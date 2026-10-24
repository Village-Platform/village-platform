# Cookie session is used only by the admin dashboard; the mobile API uses JWT bearer tokens.
Rails.application.config.session_store :cookie_store,
  key: "_aghour_admin_session",
  same_site: :lax,
  secure: Rails.env.production?,
  httponly: true
