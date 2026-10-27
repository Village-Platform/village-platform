module Subscriptions
  # Hints for the reviewer that a transfer may be reused or mistyped. The unique index already
  # blocks the exact same reference for the same method; these catch what it cannot: the same
  # payer phone across different accounts, and a reference that differs only in spacing or case
  # or was used with the other payment method.
  class DuplicateSignals
    Signal = Data.define(:kind, :subscription)
    LIMIT = 10

    def self.call(subscription) = new(subscription).call

    def initialize(subscription)
      @subscription = subscription
    end

    def call
      (same_reference + same_payer_phone).uniq { |signal| [ signal.kind, signal.subscription.id ] }
    end

    private

    def others
      Subscription.where.not(id: @subscription.id).includes(:user).latest_first.limit(LIMIT)
    end

    def same_reference
      normalized = @subscription.transaction_reference.to_s.gsub(/[^[:alnum:]]/, "").downcase
      return [] if normalized.blank?

      others.where("regexp_replace(lower(subscriptions.transaction_reference), '[^[:alnum:]]', '', 'g') = ?", normalized)
            .map { Signal.new(:reference, _1) }
    end

    def same_payer_phone
      return [] if @subscription.payer_phone.blank?

      others.where(payer_phone: @subscription.payer_phone).where.not(user_id: @subscription.user_id)
            .map { Signal.new(:payer_phone, _1) }
    end
  end
end
