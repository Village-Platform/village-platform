# Avo 4 Community — admin dashboard at /admin, super admins only.
# Docs: https://docs.avohq.io/4.0/
Avo.configure do |config|
  config.root_path = "/admin"
  config.home_path = "/admin/resources/subscriptions"
  config.app_name = -> { I18n.t("admin.app_name") }

  # Arabic UI. Avo flips the layout to right-to-left automatically for :ar.
  config.locale = :ar

  ## Authentication (our own cookie session, see Admin::SessionsController)
  config.current_user_method do
    @avo_current_admin ||= AdminSession.find_admin(session)
  end
  config.authenticate_with do
    redirect_to main_app.admin_login_path unless AdminSession.find_admin(session)
  end
  config.sign_out_path_name = :admin_logout_path

  config.click_row_to_view_record = true
  config.per_page = 25
  config.per_page_steps = [ 25, 50, 100 ]
  config.buttons_on_form_footers = true

  ## Branding: dark green + gold
  # Put the logo files in public/brand/ (logo.png, logomark.png, favicon.ico) and uncomment.
  config.appearance = {
    # logo: "/brand/logo.png",
    # logomark: "/brand/logomark.png",
    # favicon: "/brand/favicon.ico",
    scheme: :light,
    accent: :brand,
    accent_colors: {
      color:      "oklch(40% 0.08 163)", # dark green  (~#0f4433)
      content:    "oklch(33% 0.07 163)",
      foreground: "oklch(98% 0 0)"
    },
    chart_colors: [ "#0f4433", "#c9a227", "#155c45", "#d9b84a" ],
    lock: [ :accent ]
  }
end
