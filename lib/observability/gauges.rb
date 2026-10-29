module Observability
  # Observable instruments, read by the SDK on every export (OTEL_METRIC_EXPORT_INTERVAL). Registered
  # only in the web server process (see Metrics.install!).
  #
  # The SDK runs each callback in its own thread and kills it after 30s, so database reads borrow a
  # connection only inside with_connection, behind a 2s statement_timeout, and one untraced snapshot
  # serves all the business gauges of an export.
  #
  # Business counts come from the database, so every web replica reports the same value: aggregate
  # them with max(), never sum().
  module Gauges
    SNAPSHOT_TTL = 5 # seconds

    @mutex = Mutex.new
    @snapshot = nil
    @snapshot_at = nil

    class << self
      def register(meter)
        gauge(meter, "aghour.subscriptions.pending", "{subscription}", "Subscriptions waiting for review") { business[:pending] }
        gauge(meter, "aghour.subscriptions.pending.oldest_age", "s", "Age of the oldest pending subscription (0 when none)") { business[:oldest_pending_age] }
        gauge(meter, "aghour.subscriptions.current", "{subscription}", "Subscriptions in their paid period") { business[:current] }
        gauge(meter, "aghour.firms.visible", "{firm}", "Firms listed to the public (Firm.visible)") { business[:visible_firms] }

        gauge(meter, "aghour.puma.threads.max", "{thread}", "Puma max threads") { puma[:max_threads] }
        gauge(meter, "aghour.puma.threads.busy", "{thread}", "Puma threads serving a request") do
          stats = puma
          stats[:max_threads] - stats[:pool_capacity] if stats[:max_threads] && stats[:pool_capacity]
        end
        gauge(meter, "aghour.puma.backlog", "{request}", "Requests waiting for a Puma thread") { puma[:backlog] }

        gauge(meter, "aghour.db.pool.size", "{connection}", "Active Record pool size") { ActiveRecord::Base.connection_pool.stat[:size] }
        gauge(meter, "aghour.db.pool.busy", "{connection}", "Connections checked out") { ActiveRecord::Base.connection_pool.stat[:busy] }
        gauge(meter, "aghour.db.pool.waiting", "{thread}", "Threads waiting for a connection") { ActiveRecord::Base.connection_pool.stat[:waiting] }

        gauge(meter, "aghour.process.memory.rss", "By", "Resident memory of the Ruby process") { rss_bytes }
        gauge(meter, "aghour.ruby.heap.live_slots", "{slot}", "Live object slots on the Ruby heap") { GC.stat(:heap_live_slots) }
        meter.create_observable_counter("aghour.ruby.gc.count", unit: "{collection}", description: "Ruby GC runs", callback: -> { GC.count })
      end

      # Drops the cached business snapshot (specs).
      def reset!
        @mutex.synchronize { @snapshot = nil }
      end

      private

      def gauge(meter, name, unit, description, &callback)
        meter.create_observable_gauge(name, unit:, description:, callback:)
      end

      def business
        @mutex.synchronize do
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          if @snapshot.nil? || now - @snapshot_at > SNAPSHOT_TTL
            @snapshot = read_business
            @snapshot_at = now
          end
          @snapshot
        end
      end

      # Untraced: otherwise every export (30s) would add four root spans of COUNT queries to Tempo.
      def read_business
        OpenTelemetry::Common::Utilities.untraced { read_business_untraced }
      end

      def read_business_untraced
        Rails.application.executor.wrap do
          ActiveRecord::Base.connection_pool.with_connection do |connection|
            ActiveRecord::Base.transaction do
              connection.execute("SET LOCAL statement_timeout = '2s'")
              oldest = Subscription.pending.minimum(:created_at)
              {
                pending: Subscription.pending.count,
                oldest_pending_age: oldest ? (Time.current - oldest).to_f : 0,
                current: Subscription.current.count,
                visible_firms: Firm.visible.count
              }
            end
          end
        end
      end

      # Single mode only (in cluster mode the numbers are per worker, under :worker_status). Empty when
      # no Puma server runs in this process; a nil observation is skipped by the SDK.
      def puma
        Puma.stats_hash
      rescue NoMethodError
        {}
      end

      def rss_bytes
        line = File.foreach("/proc/self/status").find { |l| l.start_with?("VmRSS:") }
        line && line.split[1].to_i * 1024
      rescue Errno::ENOENT
        nil # not Linux
      end
    end
  end
end
