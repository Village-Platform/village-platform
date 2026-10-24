# Review queue. Subscriptions are created by owners from the app and changed only through
# the Approve / Reject actions, so the form fields are read-only.
class Avo::Resources::Subscription < Avo::BaseResource
  self.title = :transaction_reference
  self.translation_key = "avo.resource_translations.subscription"
  self.includes = [ :user, :subscription_plan ]
  self.attachments = [ :payment_screenshot ]
  self.search = {
    query: -> {
      term = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
      query.joins(:user).where(
        "subscriptions.transaction_reference ILIKE :t OR subscriptions.payer_phone ILIKE :t OR users.phone ILIKE :t", t: term
      )
    }
  }

  def fields
    field :id, as: :id
    field :status, as: :badge, name: "الحالة",
                   options: { warning: "pending", success: "active", danger: "rejected" }
    field :state, as: :text, name: "الوضع الحالي", only_on: [ :index, :show ] do
      I18n.t("enums.subscription.state.#{record.state}", default: record.state)
    end
    field :user, as: :belongs_to, name: "صاحب الطلب", readonly: true
    field :subscription_plan, as: :belongs_to, name: "الباقة", readonly: true
    field :payment_method, as: :select, name: "طريقة الدفع", enum: ::Subscription.payment_methods,
                           display_value: false, readonly: true
    field :amount, as: :text, name: "المبلغ", only_on: [ :index, :show ] do
      "#{(record.amount_cents / 100.0).round(2)} ج.م"
    end
    field :transaction_reference, as: :text, name: "رقم العملية", readonly: true
    field :payer_phone, as: :text, name: "رقم المحوِّل", readonly: true
    field :payment_screenshot, as: :file, name: "صورة التحويل", readonly: true, hide_on: :index
    field :notes, as: :textarea, name: "ملاحظات صاحب الطلب", readonly: true, hide_on: :index
    field :starts_at, as: :date_time, name: "يبدأ في", readonly: true
    field :ends_at, as: :date_time, name: "ينتهي في", readonly: true
    field :rejection_reason, as: :textarea, name: "سبب الرفض", readonly: true, hide_on: :index
    field :reviewed_by, as: :belongs_to, name: "تمت المراجعة بواسطة", readonly: true, hide_on: :index
    field :reviewed_at, as: :date_time, name: "تاريخ المراجعة", readonly: true, hide_on: :index
    field :created_at, as: :date_time, name: "تاريخ الطلب", only_on: [ :index, :show ]
  end

  def filters
    filter Avo::Filters::SubscriptionStatus
    filter Avo::Filters::SubscriptionPaymentMethod
  end

  def actions
    action Avo::Actions::ApproveSubscription, icon: "heroicons/outline/check-badge"
    action Avo::Actions::RejectSubscription, icon: "heroicons/outline/x-circle"
  end
end
