module Authentication
  extend ActiveSupport::Concern

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = user_from_token
  end

  def authenticate_user!
    render_error(:unauthorized, "unauthorized") unless current_user
  end

  def user_from_token
    scheme, token = request.authorization.to_s.split(" ", 2)
    return nil unless scheme&.casecmp?("Bearer")

    payload = JsonWebToken.decode(token)
    payload && User.not_deleted.find_by(id: payload["sub"])
  end

  def issue_token_for(user)
    JsonWebToken.encode({ sub: user.id })
  end
end
