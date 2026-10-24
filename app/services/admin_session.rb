# Reads the signed-in super admin from the cookie session used by the dashboard.
module AdminSession
  TTL = 12.hours

  def self.sign_in(session, user)
    session[:admin_user_id] = user.id
    session[:admin_signed_in_at] = Time.current.to_i
  end

  # Returns the super admin, or nil when missing, expired, or no longer a super admin.
  def self.find_admin(session)
    user_id = session[:admin_user_id]
    signed_in_at = session[:admin_signed_in_at]
    return nil if user_id.blank? || signed_in_at.blank?
    return nil if Time.zone.at(signed_in_at.to_i) < TTL.ago

    User.super_admin.find_by(id: user_id)
  end
end
