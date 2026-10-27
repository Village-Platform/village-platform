module Admin
  class SettingsController < BaseController
    requires_permission :super_admin

    def edit
      @values = Setting::SCHEMA.keys.index_with { Setting.get(_1) }
    end

    def update
      input = params.fetch(:settings, {}).permit(*Setting::SCHEMA.keys)
      ApplicationRecord.transaction do
        Setting::SCHEMA.each_key do |key|
          next unless input.key?(key)

          value = Setting.cast(key, input[key])
          setting = Setting.find_or_initialize_by(key:)
          next if setting.value == value && (setting.persisted? || value.nil?) # unchanged

          old = setting.value
          setting.update!(value:, updated_by: current_admin, updated_at: Time.current)
          Audit.record(actor: current_admin, action: "setting.update", subject: setting, changes: { key => [ old, value ] })
        end
      end
      redirect_to edit_admin_settings_path, notice: "تم حفظ الإعدادات."
    rescue ArgumentError
      redirect_to edit_admin_settings_path, alert: "قيمة رقمية غير صحيحة."
    end
  end
end
