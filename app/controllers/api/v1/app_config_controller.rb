module Api
  module V1
    # GET /api/v1/app_config — read by the Android app at start-up. An app whose versionCode is
    # below min_android_version shows a blocking update screen (force-update).
    class AppConfigController < BaseController
      def show
        expires_in 5.minutes, public: true
        render json: { data: Setting.client_config }
      end
    end
  end
end
