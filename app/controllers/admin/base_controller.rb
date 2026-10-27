module Admin
  # Base for all dashboard pages: Arabic, cookie session, super admins and staff.
  # Each controller names the permission it needs with `requires_permission`.
  class BaseController < ActionController::Base
    include Pagination
    include Auditing

    layout "admin"

    around_action :use_arabic
    before_action :require_admin

    helper_method :current_admin, :filter_params

    # requires_permission "firms.moderate"            — every action
    # requires_permission :super_admin, only: :update — super admins only
    def self.requires_permission(permission, **options)
      before_action(**options) { require_permission!(permission) }
    end

    rescue_from ActiveRecord::RecordNotFound do
      redirect_to admin_root_path, alert: "العنصر غير موجود."
    end

    private

    # Current index filters, for links (pagination, tabs) — see Admin::UiHelper::FILTER_KEYS.
    def filter_params(**overrides)
      request.query_parameters.symbolize_keys.slice(*Admin::UiHelper::FILTER_KEYS).merge(overrides)
    end

    def audit_source = "admin"
    def audit_actor = current_admin

    def current_admin
      @current_admin ||= AdminSession.find_admin(session)
    end

    def require_admin
      return if current_admin

      reset_session
      redirect_to admin_login_path, alert: "يجب تسجيل الدخول أولاً."
    end

    def require_permission!(permission)
      allowed = permission == :super_admin ? current_admin.super_admin? : current_admin.can?(permission)
      return if allowed

      redirect_to admin_root_path, alert: "ليس لديك صلاحية لهذه الصفحة."
    end

    def use_arabic(&action)
      I18n.with_locale(:ar, &action)
    end

    # Escaped ILIKE pattern for simple search boxes.
    def like(term)
      "%#{ActiveRecord::Base.sanitize_sql_like(term.to_s.strip)}%"
    end

    def destroy_and_redirect(record, path)
      if audited("#{record.model_name.singular}.destroy") { record.destroy }
        redirect_to path, notice: "تم الحذف."
      else
        redirect_to path, alert: record.errors.full_messages.to_sentence.presence || "لا يمكن حذف هذا العنصر."
      end
    end
  end
end
