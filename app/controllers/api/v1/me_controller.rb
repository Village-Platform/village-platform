module Api
  module V1
    class MeController < BaseController
      before_action :authenticate_user!

      def show
        render_record(current_user, UserSerializer)
      end

      def update
        current_user.update!(me_params)
        render_record(current_user, UserSerializer)
      end

      private

      def me_params
        params.require(:user).permit(:name, :email, :password, :password_confirmation)
      end
    end
  end
end
