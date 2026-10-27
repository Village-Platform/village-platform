module Api
  module V1
    class MeController < BaseController
      before_action :authenticate_user!

      # Includes the plan limits and current usage, so the app can disable "add" before it fails.
      def show
        render json: { data: UserSerializer.render(current_user).merge(entitlements: entitlements_payload) }
      end

      def update
        current_user.update!(me_params)
        render_record(current_user, UserSerializer)
      end

      private

      def entitlements_payload
        current_user.entitlements.to_h.merge(
          usage: { firms: current_user.firms.count, articles_this_month: current_user.articles_this_month }
        )
      end

      def me_params
        params.require(:user).permit(:name, :email, :password, :password_confirmation)
      end
    end
  end
end
