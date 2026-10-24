require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = ENV["ASSUME_SSL"].present?
  config.force_ssl = ENV["FORCE_SSL"].present?
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"

  config.active_support.report_deprecations = false

  # Swap to Redis / Solid Cache and Sidekiq / Solid Queue when needed.
  config.cache_store = :memory_store
  config.active_job.queue_adapter = :async

  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]
end
