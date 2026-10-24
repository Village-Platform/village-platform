# Encodes / decodes the bearer tokens used by the mobile app.
class JsonWebToken
  ALGORITHM = "HS256".freeze
  DEFAULT_TTL = 30.days

  def self.encode(payload, expires_at: DEFAULT_TTL.from_now)
    JWT.encode(payload.merge(exp: expires_at.to_i), secret, ALGORITHM)
  end

  # Returns the payload hash, or nil when the token is invalid or expired.
  def self.decode(token)
    return nil if token.blank?

    JWT.decode(token, secret, true, algorithm: ALGORITHM).first
  rescue JWT::DecodeError
    nil
  end

  def self.secret
    Rails.application.secret_key_base
  end
end
