module Api
  module V1
    # The compression targets the Android app encodes to. Public and cacheable: the app keeps
    # built-in defaults and refreshes these at start-up, so a limit can tighten without a release.
    class MediaProfilesController < BaseController
      def index
        expires_in 1.hour, public: true
        render json: { data: MediaProfile.all.map(&:as_json) }
      end
    end
  end
end
