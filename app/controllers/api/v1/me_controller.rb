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

      # DELETE /api/v1/me  { "password": "..." }
      # Re-asks for the password so a leaked token alone cannot delete the account. A wrong
      # password is 422, not 401: the app signs the user out on any 401.
      def destroy
        return render_error(:forbidden, "forbidden") if current_user.super_admin?
        return render_error(:unprocessable_content, "invalid_password") unless current_user.authenticate(params.require(:password))

        Users::DeleteAccount.call(user: current_user)
        head :no_content
      end

      private

      def me_params
        params.require(:user).permit(:name, :email, :password, :password_confirmation)
      end
    end
  end
end
