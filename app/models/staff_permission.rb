# One dashboard power granted to a staff user. The list is fixed in code (greppable, testable)
# rather than a configurable roles table: with one or two staff, a role table is configuration
# nobody maintains. Super admins hold every permission implicitly.
class StaffPermission < ApplicationRecord
  PERMISSIONS = {
    "firms.moderate" => "مراجعة الأنشطة ووسائطها",
    "subscriptions.review" => "مراجعة الاشتراكات والمدفوعات",
    "articles.moderate" => "مراجعة الأخبار والمقالات",
    "reports.handle" => "معالجة البلاغات",
    "notifications.send" => "إرسال الإشعارات",
    "categories.manage" => "إدارة التصنيفات",
    "users.manage" => "إدارة المستخدمين"
  }.freeze

  has_audit_trail

  belongs_to :user
  belongs_to :granted_by, class_name: "User", optional: true

  validates :permission, inclusion: { in: PERMISSIONS.keys }, uniqueness: { scope: :user_id }
end
