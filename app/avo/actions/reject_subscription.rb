class Avo::Actions::RejectSubscription < Avo::BaseAction
  self.name = "رفض الاشتراك"

  def fields
    field :reason, as: :textarea, name: "سبب الرفض", required: true
  end

  def handle(query:, fields:, current_user:, **)
    reason = fields[:reason].to_s.strip
    return error(I18n.t("admin.actions.reject_reason")) if reason.blank?

    done = 0
    skipped = 0

    query.each do |subscription|
      Subscriptions::Reject.call(subscription:, reviewer: current_user, reason:)
      done += 1
    rescue Subscriptions::ReviewError
      skipped += 1
    end

    succeed I18n.t("admin.actions.done", count: done) if done.positive?
    warn I18n.t("admin.actions.skipped", count: skipped) if skipped.positive?
  end
end
