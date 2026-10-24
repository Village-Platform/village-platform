require "rails_helper"

RSpec.describe "Admin Users API", type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:user) { create(:user) }

  it "lets super admins promote a user to firm admin" do
    patch "/api/v1/admin/users/#{user.id}", params: { user: { role: "firm_admin" } },
                                            headers: auth_headers(super_admin), as: :json

    expect(response).to have_http_status(:ok)
    expect(user.reload).to be_firm_admin
  end

  it "rejects an unknown role" do
    patch "/api/v1/admin/users/#{user.id}", params: { user: { role: "king" } },
                                            headers: auth_headers(super_admin), as: :json

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "forbids normal users" do
    get "/api/v1/admin/users", headers: auth_headers(user)
    expect(response).to have_http_status(:forbidden)
  end
end
