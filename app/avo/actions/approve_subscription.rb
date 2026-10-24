# Uses the same service as the API, so stacking, role promotion and notifications stay identical.
class Avo::Actions::ApproveSubscription < Avo::BaseAction
  self.name = "اعتماد الاشتراك"
  self.message = "تأكد من وصول التحويل قبل الاعتماد. سيتم تفعيل الاشتراك وإشعار صاحب المنشأة."

  def handle(query:, current_user:, **)
    done = 0
    skipped = 0

    query.each do |subscription|
      Subscriptions::Approve.call(subscription:, reviewer: current_user)
      done += 1
    rescue Subscriptions::ReviewError
      skipped += 1
    end

    succeed I18n.t("admin.actions.done", count: done) if done.positive?
    warn I18n.t("admin.actions.skipped", count: skipped) if skipped.positive?
  end
end
