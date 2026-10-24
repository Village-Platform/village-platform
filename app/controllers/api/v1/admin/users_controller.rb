module Api
  module V1
    module Admin
      class UsersController < BaseController
        before_action :authenticate_user!

        # GET /api/v1/admin/users?role=firm_admin
        def index
          authorize User
          scope = User.order(:id)
          scope = scope.where(role: params[:role]) if User.roles.key?(params[:role])

          records, meta = paginate(scope)
          render_collection(records, meta, UserSerializer)
        end

        # PATCH /api/v1/admin/users/:id  { "user": { "role": "firm_admin" } }
        def update
          user = User.find(params[:id])
          authorize user
          user.update!(params.require(:user).permit(:role))
          render_record(user, UserSerializer)
        end
      end
    end
  end
end
