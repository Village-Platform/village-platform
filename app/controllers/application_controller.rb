class ApplicationController < ActionController::API
  include Pundit::Authorization
  include Authentication
  include ErrorHandling
  include Pagination
  include Auditing

  around_action :switch_locale

  private

  def audit_source = "api"
  def audit_actor = current_user

  def switch_locale(&action)
    requested = request.headers["Accept-Language"].to_s[0, 2]&.downcase
    locale = I18n.available_locales.map(&:to_s).include?(requested) ? requested : I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def render_collection(records, meta, serializer)
    render json: { data: records.map { |r| serializer.render(r) }, meta: }
  end

  def render_record(record, serializer, status: :ok)
    render json: { data: serializer.render(record) }, status:
  end
end
