require "rails_helper"

RSpec.describe Fcm::Client do
  let(:response_class) do
    Struct.new(:code, :body, :headers) do
      def [](name) = headers[name]
    end
  end
  let(:requests) { [] }
  let(:responses) { [] }
  let(:transport) do
    ->(uri, request) {
      requests << [ request.method, uri.to_s, request.body ]
      responses.shift || response_class.new("200", '{"name":"projects/p/messages/1"}', {})
    }
  end
  # Stands in for the fcm gem's FCM instance: send_v1 returns { status_code:, body:, headers: }.
  let(:sent) { [] }
  let(:send_results) { [] }
  let(:sender) do
    double("FCM").tap do |fcm|
      allow(fcm).to receive(:send_v1) do |message|
        sent << message
        send_results.shift || { status_code: 200, body: '{"name":"projects/p/messages/1"}', headers: {} }
      end
    end
  end
  let(:key_json) { { type: "service_account", project_id: "p", private_key: "-----BEGIN PRIVATE KEY-----\nx\n" }.to_json }
  let(:client) do
    described_class.new(credentials_json: key_json, transport:, token_source: -> { "tok" }, sender:)
  end

  def send_returns(code, body = "{}", headers = {})
    send_results << { status_code: code, body:, headers: }
  end
  let(:message) { Fcm::Message.build(target: { token: "t" }, title: "T", body: "B", data: {}) }

  def respond(code, body = "{}", headers = {})
    responses << response_class.new(code.to_s, body, headers)
  end

  def fcm_error(status, error_code)
    { error: { status:, details: [ { "@type" => "type.googleapis.com/google.firebase.fcm.v1.FcmError", errorCode: error_code } ] } }.to_json
  end

  describe "#deliver" do
    it "sends through the fcm gem and returns the message name" do
      expect(client.deliver(message)).to eq("projects/p/messages/1")
      expect(sent).to eq([ message ])
    end

    it "raises Unregistered on 404 UNREGISTERED" do
      send_returns(404, fcm_error("NOT_FOUND", "UNREGISTERED"))
      expect { client.deliver(message) }.to raise_error(Fcm::Unregistered)
    end

    it "raises InvalidArgument on 400" do
      send_returns(400, fcm_error("INVALID_ARGUMENT", "INVALID_ARGUMENT"))
      expect { client.deliver(message) }.to raise_error(Fcm::InvalidArgument)
    end

    it "raises Retryable with retry_after on 429" do
      send_returns(429, fcm_error("RESOURCE_EXHAUSTED", "QUOTA_EXCEEDED"), "retry-after" => "30")
      expect { client.deliver(message) }.to raise_error(Fcm::Retryable) { |e| expect(e.retry_after).to eq(30) }
    end

    it "raises Retryable on 503 without Retry-After" do
      send_returns(503)
      expect { client.deliver(message) }.to raise_error(Fcm::Retryable) { |e| expect(e.retry_after).to be_nil }
    end

    it "raises AuthError on 401 and 403" do
      send_returns(401)
      expect { client.deliver(message) }.to raise_error(Fcm::AuthError)
      send_returns(403, fcm_error("PERMISSION_DENIED", "SENDER_ID_MISMATCH"))
      expect { client.deliver(message) }.to raise_error(Fcm::AuthError)
    end

    it "raises a plain Error, not Unregistered, on a 404 without UNREGISTERED" do
      send_returns(404, "{}")
      expect { client.deliver(message) }.to raise_error(Fcm::Error) { |e| expect(e).not_to be_a(Fcm::Unregistered) }
    end

    it "maps the gem's network and token failures" do
      allow(sender).to receive(:send_v1).and_raise(Faraday::TimeoutError)
      expect { client.deliver(message) }.to raise_error(Fcm::Retryable)

      allow(sender).to receive(:send_v1).and_raise(Signet::AuthorizationError.new("invalid_grant"))
      expect { client.deliver(message) }.to raise_error(Fcm::AuthError)
    end

    it "raises InvalidArgument when the gem silently sends nothing" do
      allow(sender).to receive(:send_v1).and_return(nil)
      expect { client.deliver(message) }.to raise_error(Fcm::InvalidArgument)
    end

    it "is a no-op when no credentials are set" do
      disabled = described_class.new(credentials_json: nil, transport:, sender:)
      expect(disabled).not_to be_enabled
      expect(disabled.deliver(message)).to eq("disabled")
      expect(sent).to be_empty
    end

    it "builds the gem client from the credentials JSON" do
      real = described_class.new(credentials_json: key_json, transport:)
      expect(real.send(:sender)).to be_a(FCM)
    end
  end

  describe "credentials" do
    it "reads the key from a file path" do
      Tempfile.create([ "fcm", ".json" ]) do |file|
        file.write(key_json)
        file.flush
        client = described_class.new(credentials_json: file.path, sender:)
        expect(client).to be_enabled
        expect(client.deliver(message)).to eq("projects/p/messages/1")
      end
    end

    it "rejects the Android google-services.json with a clear message" do
      android = { project_info: { project_id: "p" }, client: [] }.to_json
      expect { described_class.new(credentials_json: android) }
        .to raise_error(ArgumentError, /google-services\.json.*service-account/)
    end

    it "names a path that does not exist" do
      expect { described_class.new(credentials_json: "config/fcm/missing.json") }
        .to raise_error(ArgumentError, %r{config/fcm/missing\.json})
    end
  end

  describe "topics" do
    it "subscribes each token and returns the ones FCM rejected" do
      respond(200)
      respond(404, fcm_error("NOT_FOUND", "UNREGISTERED"))
      respond(409) # already subscribed counts as success

      expect(client.subscribe("news", %w[ a b c ])).to eq(%w[ b ])
      expect(requests.map(&:first)).to eq(%w[ POST POST POST ])
      expect(requests.first[1]).to eq("https://fcm.googleapis.com/v1/projects/p/registrations/a/topicSubscriptions?topic_name=news")
    end

    it "unsubscribes each token and treats not-subscribed as success" do
      respond(200)
      respond(404)

      expect(client.unsubscribe("news", %w[ a b ])).to eq([])
      expect(requests.last[0..1]).to eq([ "DELETE", "https://fcm.googleapis.com/v1/projects/p/registrations/b/topicSubscriptions/news" ])
    end

    it "keeps a token on a bare 404 or a 400 instead of reporting it rejected" do
      respond(404, "{}") # e.g. a wrong path: says nothing about the token
      expect { client.subscribe("news", %w[ a ]) }.to raise_error(Fcm::Error)

      respond(400, fcm_error("INVALID_ARGUMENT", "INVALID_ARGUMENT"))
      expect(client.subscribe("news", %w[ b ])).to eq([])
    end

    it "maps network failures to Retryable" do
      failing = described_class.new(credentials_json: key_json, token_source: -> { "tok" },
                                    transport: ->(*) { raise Net::ReadTimeout })
      expect { failing.subscribe("news", %w[ a ]) }.to raise_error(Fcm::Retryable)
    end

    it "raises Retryable on a 503 from the topic API" do
      respond(503)
      expect { client.subscribe("news", %w[ a ]) }.to raise_error(Fcm::Retryable)
    end
  end
end
