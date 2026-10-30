class ApplicationController < ActionController::API
  include Pundit::Authorization
  include Authentication
  include ErrorHandling
  include Pagination
  include Filterable

  around_action :switch_locale

  private

  def switch_locale(&action)
    requested = request.headers["Accept-Language"].to_s[0, 2]&.downcase
    locale = I18n.available_locales.map(&:to_s).include?(requested) ? requested : I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  # Extra keywords (e.g. user:) are passed on to serializers that take them; others get none.
  def render_collection(records, meta, serializer, **context)
    render json: { data: records.map { |r| serializer.render(r, **context) }, meta: }
  end

  def render_record(record, serializer, status: :ok, **context)
    render json: { data: serializer.render(record, **context) }, status:
  end
end
