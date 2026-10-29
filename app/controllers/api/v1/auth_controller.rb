module Api
  module V1
    class AuthController < BaseController
      # POST /api/v1/auth/register
      # { "user": { "name", "phone", "email", "password", "password_confirmation" } }
      # Everyone registers as a normal user; roles are granted by a super admin.
      def register
        user = User.create!(register_params)
        render json: auth_payload(user), status: :created
      end

      # POST /api/v1/auth/login
      # { "phone": "...", "password": "..." }
      def login
        phone = User.normalize_value_for(:phone, params.require(:phone))
        user = User.not_deleted.find_by(phone:)

        if user&.authenticate(params.require(:password))
          render json: auth_payload(user)
        else
          render_error(:unauthorized, "invalid_credentials")
        end
      end

      private

      def register_params
        params.require(:user).permit(:name, :phone, :email, :password, :password_confirmation)
      end

      def auth_payload(user)
        { data: { token: issue_token_for(user), user: UserSerializer.render(user) } }
      end
    end
  end
end
