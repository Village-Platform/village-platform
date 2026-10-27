module Notifications
  # Sends one announcement to every recipient of a Broadcast.
  #
  # Idempotent at two levels: the broadcast row is found by its idempotency key (a double-click
  # sends once), and each notification has dedupe_key "broadcast:<id>:<user id>" inserted with
  # ON CONFLICT DO NOTHING (a retried fan-out skips who already got it).
  #
  # Fan-out runs in the request with batched inserts — fine for hundreds or a few thousand users.
  # At tens of thousands it would outlive Cloudflare's 100s timeout; move it to a job then.
  class Broadcast
    BATCH = 1_000

    def self.call(**) = new(**).call

    def initialize(actor:, idempotency_key:, audience: nil, title: nil, body: nil, audience_params: {})
      @actor = actor
      @attributes = { idempotency_key:, audience:, title:, body:, audience_params: audience_params.to_h.compact_blank }
    end

    def call
      broadcast = ::Broadcast.find_by(idempotency_key: @attributes[:idempotency_key])
      return broadcast if broadcast

      broadcast = Audit.operation("broadcast.send", actor: @actor) { ::Broadcast.create!(@attributes.merge(actor: @actor)) }
      broadcast.update!(recipients_count: deliver(broadcast))
      broadcast
    rescue ActiveRecord::RecordNotUnique
      ::Broadcast.find_by!(idempotency_key: @attributes[:idempotency_key])
    end

    private

    def deliver(broadcast)
      now = Time.current
      title, body = I18n.with_locale(I18n.default_locale) do
        [ I18n.t("notifications.broadcast.title", title: broadcast.title),
          I18n.t("notifications.broadcast.body", body: broadcast.body) ]
      end

      sent = 0
      broadcast.recipients.in_batches(of: BATCH) do |users|
        rows = users.pluck(:id).map do |user_id|
          { user_id:, kind: Notification.kinds[:broadcast], title:, body:, data: { broadcast_id: broadcast.id },
            dedupe_key: "broadcast:#{broadcast.id}:#{user_id}", created_at: now, updated_at: now }
        end
        sent += Notification.insert_all(rows, returning: [ :id ]).length
      end
      sent
    end
  end
end
