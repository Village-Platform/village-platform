module Observability
  # Turns every controller action (process_action.action_controller) into RED metrics: rate and
  # errors from the count by status, duration from the histogram. The route is controller#action —
  # a closed set, unlike the path, which carries ids.
  #
  # For the API it also counts requests by client app version, which is what tells us when an old
  # contract has no callers left. Old app builds send no header, so a missing one is "unknown".
  module Requests
    SURFACES = { "Api" => "api", "Admin" => "admin", "Internal" => "internal" }.freeze
    PLATFORMS = %w[ android ios ].freeze
    # The header is client input: keep major.minor only, so the label set stays bounded.
    APP_VERSION = /\A(\d{1,3})\.(\d{1,3})/

    class << self
      def record(event)
        payload = event.payload
        controller = payload[:controller].to_s
        return if controller == "Rails::HealthController" # /up, polled by probes every few seconds

        surface = SURFACES.fetch(controller.split("::").first, "other")
        Metrics.record(:http_request_duration, event.duration / 1000.0,
                       "http.route" => "#{controller}##{payload[:action]}",
                       "http.request.method" => payload[:method].to_s,
                       "http.response.status_code" => status(payload),
                       "app.surface" => surface)
        record_client(payload[:headers]) if surface == "api" && payload[:headers]
      end

      private

      # An exception that no rescue_from handled leaves status nil; Rails answers it with a 500.
      def status(payload)
        payload[:status] || (payload[:exception] ? 500 : 0)
      end

      def record_client(headers)
        platform = headers["X-App-Platform"].to_s.downcase
        version = headers["X-App-Version"].to_s[APP_VERSION]
        Metrics.increment(:client_requests,
                          "client.platform" => PLATFORMS.include?(platform) ? platform : "unknown",
                          "client.app_version" => version || "unknown")
      end
    end
  end
end
