module Admin
  # Grants and revokes a staff user's permissions. Super admins only; a user never edits their own.
  class StaffPermissionsController < BaseController
    requires_permission :super_admin

    def update
      user = User.staff.find(params[:user_id])
      wanted = Array(params[:permissions]) & StaffPermission::PERMISSIONS.keys
      current = user.staff_permissions.pluck(:permission)

      # One version per granted or revoked StaffPermission row (destroy, not delete_all, so
      # PaperTrail sees it).
      ApplicationRecord.transaction do
        audited("user.grant") do
          (wanted - current).each { |permission| user.staff_permissions.create!(permission:, granted_by: current_admin) }
        end
        audited("user.revoke") { user.staff_permissions.where(permission: current - wanted).destroy_all }
      end

      redirect_to admin_user_path(user), notice: "تم حفظ الصلاحيات."
    end
  end
end
