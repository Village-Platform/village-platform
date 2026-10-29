# Examples tagged :metrics get Observability::Metrics installed on an in-memory meter provider,
# with the observable gauges, and read values back with metric_value:
#
#   it "counts the error", :metrics do
#     get "/api/v1/firms/0"
#     expect(metric_value("aghour.api.errors", code: "not_found")).to eq(1)
#   end
module MetricsHelpers
  # Counter: sum of the matching points. Histogram: number of recordings. Gauge: the value.
  # A point matches when its attributes include all of the given ones.
  # (Data points are Structs, which are Enumerable: #count exists on every one of them.)
  def metric_value(name, **attributes)
    points = metric_points(name, **attributes)
    points.sum { |point| point.respond_to?(:bucket_counts) ? point.count : point.value }
  end

  def metric_points(name, **attributes)
    @metrics_reader.reset
    @metrics_reader.pull
    metric = @metrics_reader.metric_snapshots.find { |m| m.name == name }
    return [] unless metric

    wanted = attributes.to_h { |k, v| [ k.to_s, v.is_a?(Symbol) ? v.to_s : v ] }
    metric.data_points.select { |point| wanted <= point.attributes }
  end
end

RSpec.configure do |config|
  config.include MetricsHelpers, :metrics

  config.before(:each, :metrics) do
    @metrics_reader = OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new
    provider = OpenTelemetry::SDK::Metrics::MeterProvider.new
    provider.add_metric_reader(@metrics_reader)
    Observability::Gauges.reset!
    Observability::Metrics.install!(provider, observe: true)
  end

  config.after(:each, :metrics) { Observability::Metrics.uninstall! }
end
