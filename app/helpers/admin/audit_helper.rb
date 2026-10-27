module Admin
  module AuditHelper
    ACTION_LABELS = {
      "create" => "إضافة", "update" => "تعديل", "destroy" => "حذف",
      "approve" => "اعتماد", "reject" => "رفض", "suspend" => "إيقاف", "promote" => "ترقية",
      "grant" => "منح صلاحية", "revoke" => "سحب صلاحية", "broadcast" => "إرسال إشعار",
      "feature" => "تمييز", "resolve" => "معالجة", "dismiss" => "تجاهل"
    }.freeze

    SUBJECT_LABELS = {
      "Firm" => "نشاط", "User" => "مستخدم", "Subscription" => "اشتراك", "SubscriptionPlan" => "باقة",
      "Article" => "مقال", "Category" => "تصنيف", "FirmMedium" => "وسائط", "Setting" => "إعداد",
      "Report" => "بلاغ", "Broadcast" => "إشعار جماعي", "StaffPermission" => "صلاحية", "CategoryField" => "حقل تصنيف", "FeaturedPlacement" => "تمييز"
    }.freeze

    def audit_action_label(action)
      verb = action.to_s.split(".").last
      ACTION_LABELS.fetch(verb, verb)
    end

    def audit_subject_label(type)
      SUBJECT_LABELS.fetch(type, type)
    end

    # "attr: old → new" lines, values shortened so one long description cannot flood the page.
    def audit_changes(changeset)
      return "—" if changeset.blank?

      lines = changeset.map do |attribute, (old_value, new_value)|
        tag.li do
          safe_join([ tag.code(attribute), ": ", audit_value(old_value), " ← ", audit_value(new_value) ])
        end
      end
      tag.ul(safe_join(lines), class: "audit-changes")
    end

    private

    def audit_value(value)
      value.nil? ? "—" : value.to_s.truncate(60)
    end
  end
end
