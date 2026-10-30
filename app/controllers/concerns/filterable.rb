# Applies ransack filters and sorts from `f[...]` to a scope.
#
# Call it on a scope that is already policy-scoped: a filter can then only narrow what a policy
# allows, never widen it. The caller is passed as ransack's auth_object, which picks the
# allowlist tier declared with RansackTiers. Conditions outside the caller's tier are ignored
# rather than raised, so an old app version sending an unknown filter still gets an answer.
#
# `q` is deliberately not touched: it stays the plain-text search the shipped Android app sends.
module Filterable
  extend ActiveSupport::Concern

  included do
    helper_method :filter_object if respond_to?(:helper_method)
  end

  private

  def filter(scope)
    @filter_object = scope.ransack(filter_conditions, auth_object: filter_auth_object)
    return @filter_object.result if @filter_object.sorts.empty?

    # An explicit sort replaces the endpoint's default order rather than trailing behind it,
    # with id as a tiebreak so pages do not shuffle. Ransack keeps only sorts on allowlisted
    # attributes, so a sort on a private field never gets here.
    scope.unscope(:order).ransack(filter_conditions, auth_object: filter_auth_object)
         .result.order(id: :asc)
  end

  def filter_object = @filter_object

  # Ransack's allowlists are the security boundary here, not strong parameters: every key is
  # checked against the caller's tier and anything else is dropped.
  def filter_conditions
    raw = params[:f]
    raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : {}
  end

  def filter_auth_object = current_user
end
