module Admin
  # Grants and revokes a staff user's permissions. Super admins only; a user never edits their own.
  class StaffPermissionsController < BaseController
    requires_permission :super_admin

    def update
      user = User.staff.find(params[:user_id])
      wanted = Array(params[:permissions]) & StaffPermission::PERMISSIONS.keys
      current = user.staff_permissions.pluck(:permission)

      ApplicationRecord.transaction do
        (wanted - current).each do |permission|
          granted = user.staff_permissions.create!(permission:, granted_by: current_admin)
          Audit.record(actor: current_admin, action: "user.grant", subject: user, changes: { "permission" => [ nil, granted.permission ] })
        end
        (current - wanted).each do |permission|
          user.staff_permissions.where(permission:).delete_all
          Audit.record(actor: current_admin, action: "user.revoke", subject: user, changes: { "permission" => [ permission, nil ] })
        end
      end

      redirect_to admin_user_path(user), notice: "تم حفظ الصلاحيات."
    end
  end
end
