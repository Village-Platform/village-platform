module Admin
  # Stores the dashboard's light/dark preference.
  #
  # The stored value is interpolated into an HTML attribute on <html>, so it is checked
  # against an allowlist rather than trusted: anything else clears the cookie and the
  # dashboard falls back to the operating system's preference.
  class ThemeController < BaseController
    THEMES = %w[ light dark ].freeze

    def update
      theme = params[:theme].to_s

      if THEMES.include?(theme)
        cookies.permanent[:admin_theme] = theme
      else
        cookies.delete(:admin_theme)
      end

      redirect_back fallback_location: admin_root_path
    end
  end
end
