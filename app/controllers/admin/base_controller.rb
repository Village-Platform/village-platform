module Admin
  # Base for all dashboard pages: Arabic, cookie session, super admins only.
  class BaseController < ActionController::Base
    include Pagination

    layout "admin"

    around_action :use_arabic
    before_action :require_admin

    helper_method :current_admin

    rescue_from ActiveRecord::RecordNotFound do
      redirect_to admin_root_path, alert: "العنصر غير موجود."
    end

    private

    def current_admin
      @current_admin ||= AdminSession.find_admin(session)
    end

    def require_admin
      return if current_admin

      reset_session
      redirect_to admin_login_path, alert: "يجب تسجيل الدخول أولاً."
    end

    def use_arabic(&action)
      I18n.with_locale(:ar, &action)
    end

    # Escaped ILIKE pattern for simple search boxes.
    def like(term)
      "%#{ActiveRecord::Base.sanitize_sql_like(term.to_s.strip)}%"
    end

    def destroy_and_redirect(record, path)
      if record.destroy
        redirect_to path, notice: "تم الحذف."
      else
        redirect_to path, alert: record.errors.full_messages.to_sentence.presence || "لا يمكن حذف هذا العنصر."
      end
    end
  end
end
