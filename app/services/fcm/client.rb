require "fcm"
require "googleauth"

module Fcm
  # The adapter between the app and Google: callers see these methods and the Fcm::* errors only.
  #
  # Sending goes through the fcm gem (FCM#send_v1, HTTP v1). The gem reports failures as a status
  # hash instead of raising, and asks Google for a new access token on every send; both are fine
  # here because a campaign is one topic send and a user has a handful of devices.
  #
  # Topic membership does NOT use the gem: its topic methods call the Instance ID API, deprecated,
  # closed to projects not onboarded before 2026-10-01 and turned down on 2027-09-29. It uses the
  # topicSubscriptions REST API instead, one call per token, over Net::HTTP.
  #
  # FCM_SERVICE_ACCOUNT_JSON holds the service-account key itself, or a path to it (relative to the
  # app root, e.g. config/fcm/dev/service-account.json, which is git-ignored). Without it
  # (development without Firebase, CI) every call is a logged no-op.
  class Client
    BASE_URL = "https://fcm.googleapis.com/v1/projects"
    SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

    DEFAULT_TRANSPORT = ->(uri, request) {
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { |http| http.request(request) }
    }

    def initialize(credentials_json: ENV["FCM_SERVICE_ACCOUNT_JSON"].presence, transport: DEFAULT_TRANSPORT,
                   token_source: nil, sender: nil)
      @credentials_json = load_credentials(credentials_json)
      @project_id = JSON.parse(@credentials_json).fetch("project_id") if @credentials_json
      @transport = transport
      @token_source = token_source || method(:oauth_token)
      @sender = sender
      @mutex = Mutex.new
    end

    def enabled?
      @credentials_json.present?
    end

    # Returns FCM's message name ("projects/p/messages/123"), or "disabled".
    def deliver(message)
      return disabled("deliver") unless enabled?

      result = translate_errors { sender.send_v1(message) }
      # The gem returns nil, without sending, when it dislikes a topic name or condition.
      raise InvalidArgument, "FCM message rejected by the fcm gem before sending" if result.nil?

      code = result[:status_code].to_i
      body = result[:body].to_s
      raise error_for(code, body, header(result[:headers], "Retry-After")) unless code.between?(200, 299)

      JSON.parse(body).fetch("name")
    end

    # Both return the tokens FCM reported UNREGISTERED; the caller deletes those devices. Nothing
    # else ever marks a token dead: a 400 is logged and the token kept, and a 404 without that code
    # (a wrong path, say) raises, so a mistake on our side cannot wipe the devices table.
    def subscribe(topic_key, tokens)
      each_token(tokens) do |token|
        path = "#{BASE_URL}/#{@project_id}/registrations/#{encode(token)}/topicSubscriptions?topic_name=#{encode(topic_key)}"
        request(Net::HTTP::Post, path, {}, ok: [ 409 ]) # 409: already subscribed
      end
    end

    def unsubscribe(topic_key, tokens)
      each_token(tokens) do |token|
        path = "#{BASE_URL}/#{@project_id}/registrations/#{encode(token)}/topicSubscriptions/#{encode(topic_key)}"
        request(Net::HTTP::Delete, path, nil, ok: [ 404 ]) # 404: was not subscribed
      end
    end

    private

    # Fails at boot-time use with an actionable message rather than with an obscure OAuth error on
    # the first push. The usual mistake is the Android google-services.json, which cannot send.
    def load_credentials(value)
      return if value.blank?

      json = value.lstrip.start_with?("{") ? value : read_key_file(value)
      parsed = JSON.parse(json)
      return json if parsed["type"] == "service_account" && parsed["private_key"].present?

      kind = parsed.key?("project_info") ? "the Android google-services.json" : "not a service-account key"
      raise ArgumentError, "FCM_SERVICE_ACCOUNT_JSON is #{kind}, which cannot send. Use a service-account " \
                           "private key: Firebase console > Project settings > Service accounts > Generate new private key."
    end

    def read_key_file(path)
      full = Pathname(path).absolute? ? Pathname(path) : Rails.root.join(path)
      raise ArgumentError, "FCM_SERVICE_ACCOUNT_JSON points to #{path}, which does not exist" unless full.file?

      full.read
    end

    def each_token(tokens)
      unless enabled?
        disabled("topics")
        return []
      end

      tokens.each_with_object([]) do |token, rejected|
        yield token
      rescue Unregistered
        rejected << token
      rescue InvalidArgument => e
        Rails.logger.warn("[Fcm] topic call refused, token kept: #{e.message}")
      end
    end

    def request(klass, url, payload, ok: [])
      uri = URI(url)
      request = klass.new(uri, "Authorization" => "Bearer #{@token_source.call}", "Content-Type" => "application/json")
      request.body = payload.to_json if payload
      response = translate_errors { @transport.call(uri, request) }
      code = response.code.to_i
      return response if code.between?(200, 299) || ok.include?(code)

      raise error_for(code, response.body, response["Retry-After"])
    end

    def error_for(code, body, retry_after_header)
      error_code = parse_error_code(body)
      message = "FCM #{code} #{error_code}".strip
      case code
      when 401, 403 then AuthError.new(message)
      when 404 then error_code == "UNREGISTERED" ? Unregistered.new(message) : Error.new(message)
      when 400 then InvalidArgument.new(message)
      when 429, 500..599
        retry_after = retry_after_header&.then { |value| Integer(value, exception: false) }
        Retryable.new(message, retry_after:)
      else Error.new(message)
      end
    end

    NETWORK_ERRORS = [ Faraday::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, IOError,
                       Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, OpenSSL::SSL::SSLError ].freeze

    # Everything that can go wrong on the wire becomes an Fcm::* error, so jobs only handle those.
    # Signet raises AuthorizationError for a revoked or wrong key (invalid_grant).
    def translate_errors
      yield
    rescue *NETWORK_ERRORS, Signet::RemoteServerError, Signet::UnexpectedStatusError => e
      raise Retryable, "#{e.class}: #{e.message}"
    rescue Signet::AuthorizationError => e
      raise AuthError, "#{e.class}: #{e.message}"
    end

    # The FCM-specific code is in error.details[] (type FcmError), not in error.status.
    def parse_error_code(body)
      details = JSON.parse(body.to_s).dig("error", "details") || []
      details.filter_map { |detail| detail["errorCode"] }.first
    rescue JSON::ParserError
      nil
    end

    # Built lazily: the gem reads the key once and keeps its authorizer.
    def sender
      @sender ||= FCM.new(StringIO.new(@credentials_json), @project_id, timeout: 10, open_timeout: 5)
    end

    # Faraday's headers are case-insensitive; a plain Hash (specs) is not.
    def header(headers, name)
      return if headers.nil?

      headers[name] || headers.find { |key, _| key.to_s.casecmp?(name) }&.last
    end

    def encode(value)
      ERB::Util.url_encode(value)
    end

    # Access tokens last an hour; refresh a minute early. Puma is threaded, hence the mutex.
    def oauth_token
      @mutex.synchronize do
        @credentials ||= Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: StringIO.new(@credentials_json), scope: SCOPE
        )
        @credentials.fetch_access_token! if @credentials.access_token.nil? || @credentials.expires_within?(60)
        @credentials.access_token
      end
    end

    def disabled(action)
      Rails.logger.info("[Fcm] #{action} skipped: FCM_SERVICE_ACCOUNT_JSON is not set")
      "disabled"
    end
  end
end
