module Pagination
  extend ActiveSupport::Concern

  include Pagy::Method

  DEFAULT_PER_PAGE = 12
  MAX_PER_PAGE = 100

  private

  # Returns [records, meta]; the Pagy object is kept in @pagy for the admin pager.
  #
  # `meta` is a contract with the Android app, so it keeps its shape and its edge cases rather
  # than Pagy's: an empty list has 0 pages (Pagy says 1), and a per_page of 0 or below is
  # clamped to 1 (Pagy falls back to the default for 0 and raises for negatives).
  def paginate(scope)
    @pagy, records = pagy(:offset, scope, request: pagination_request,
                          limit: DEFAULT_PER_PAGE, client_limit: MAX_PER_PAGE, limit_key: "per_page")
    meta = { page: @pagy.page, per_page: @pagy.limit, total: @pagy.count,
             total_pages: @pagy.count.zero? ? 0 : @pagy.last }

    [ records, meta ]
  end

  # Pagy reads page and per_page from this hash and builds page links from its path and params,
  # so per_page is clamped here once and the links carry the clamped value.
  def pagination_request
    query = request.query_parameters
    query = query.merge("per_page" => query["per_page"].to_i.clamp(1, MAX_PER_PAGE).to_s) if query.key?("per_page")

    { base_url: request.base_url, path: request.path, params: query }
  end
end
