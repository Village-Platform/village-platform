module RequestHelpers
  def json
    response.parsed_body
  end

  def auth_headers(user)
    { "Authorization" => "Bearer #{JsonWebToken.encode({ sub: user.id })}" }
  end
end
