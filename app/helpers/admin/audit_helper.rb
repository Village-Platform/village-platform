module Admin
  module AuditHelper
    VERB_LABELS = {
      "create" => "إضافة", "update" => "تعديل", "destroy" => "حذف",
      "approve" => "اعتماد", "reject" => "رفض", "suspend" => "إيقاف", "promote" => "ترقية",
      "grant" => "منح صلاحية", "revoke" => "سحب صلاحية", "send" => "إرسال إشعار", "unpublish" => "إلغاء النشر",
      "feature" => "تمييز", "resolve" => "معالجة", "dismiss" => "تجاهل", "password_reset" => "تغيير كلمة المرور"
    }.freeze

    SUBJECT_LABELS = {
      "Firm" => "نشاط", "User" => "مستخدم", "Subscription" => "اشتراك", "SubscriptionPlan" => "باقة",
      "Article" => "مقال", "Category" => "تصنيف", "FirmMedium" => "وسائط", "Setting" => "إعداد",
      "Report" => "بلاغ", "Broadcast" => "إشعار جماعي", "FeaturedPlacement" => "تمييز",
      "StaffPermission" => "صلاحية", "CategoryField" => "حقل تصنيف"
    }.freeze

    SOURCE_LABELS = { "api" => "التطبيق", "admin" => "اللوحة", "cron" => "مهمة مجدولة", "system" => "النظام" }.freeze
    HIDDEN_ATTRIBUTES = %w[id created_at updated_at].freeze

    # The business operation ("firm.suspend") when one was named, else PaperTrail's event.
    def audit_action_label(version)
      verb = version.operation.to_s.split(".").last || version.event
      VERB_LABELS.fetch(verb, verb)
    end

    def audit_subject_label(type)
      SUBJECT_LABELS.fetch(type, type)
    end

    def audit_source_label(source)
      SOURCE_LABELS.fetch(source.to_s, source)
    end

    # Users behind the versions' whodunnit ids, loaded in one query.
    def audit_actors(versions)
      User.where(id: versions.map(&:whodunnit).compact.uniq).index_by { |user| user.id.to_s }
    end

    # "attr: old → new" lines. A deletion shows what the record held.
    def audit_changes(version)
      changes = version.object_changes.presence ||
                (version.object || {}).transform_values { |value| [ value, nil ] }
      changes = changes.except(*HIDDEN_ATTRIBUTES)
      return "—" if changes.blank?

      lines = changes.map do |attribute, (old_value, new_value)|
        tag.li { safe_join([ tag.code(attribute), ": ", audit_value(old_value), " ← ", audit_value(new_value) ]) }
      end
      tag.ul(safe_join(lines), class: "audit-changes")
    end

    private

    def audit_value(value)
      value.nil? ? "—" : value.to_s.truncate(60)
    end
  end
end
