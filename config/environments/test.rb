Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?

  config.consider_all_requests_local = true
  config.cache_store = :null_store

  # Render exception templates for rescuable exceptions and raise for other exceptions.
  config.action_dispatch.show_exceptions = :rescuable

  config.active_support.deprecation = :stderr
  config.action_controller.raise_on_missing_callback_actions = true
end
