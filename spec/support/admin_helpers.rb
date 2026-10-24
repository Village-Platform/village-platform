module AdminHelpers
  def sign_in_admin(user = create(:user, :super_admin, password: "password123"))
    post "/admin/login", params: { phone: user.phone, password: "password123" }
    user
  end
end

RSpec.configure do |config|
  config.include AdminHelpers, type: :request
end
