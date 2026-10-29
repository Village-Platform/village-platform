# Telemetry for the API: config/initializers/opentelemetry.rb wires it, deploy/observability runs
# the collector, Prometheus, Tempo, Loki and Grafana.
module Observability
  # Log tag with the current trace id, so Grafana can jump from a log line to its trace.
  # Blank (and dropped by TaggedLogging) when tracing is off.
  def self.log_tag(_request = nil)
    context = OpenTelemetry::Trace.current_span.context
    "trace=#{context.hex_trace_id}" if context.valid?
  end
end
