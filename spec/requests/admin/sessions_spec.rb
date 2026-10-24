require "rails_helper"

RSpec.describe "Admin dashboard login", type: :request do
  let(:super_admin) { create(:user, :super_admin, phone: "01000000001", password: "password123") }

  it "renders the Arabic RTL login page" do
    get "/admin/login"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('dir="rtl"')
  end

  it "redirects guests from the dashboard to the login page" do
    get "/admin/resources/subscriptions"

    expect(response).to redirect_to("/admin/login")
  end

  it "signs in a super admin and opens the dashboard" do
    post "/admin/login", params: { phone: super_admin.phone, password: "password123" }
    expect(response).to redirect_to("/admin")

    get "/admin/resources/subscriptions"
    expect(response).to have_http_status(:ok)
  end

  it "refuses non super admins even with the right password" do
    owner = create(:user, :firm_admin, password: "password123")

    post "/admin/login", params: { phone: owner.phone, password: "password123" }

    expect(response).to have_http_status(:unprocessable_content)
    get "/admin/resources/subscriptions"
    expect(response).to redirect_to("/admin/login")
  end

  it "refuses a wrong password" do
    post "/admin/login", params: { phone: super_admin.phone, password: "wrong-pass" }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "expires the session after 12 hours" do
    post "/admin/login", params: { phone: super_admin.phone, password: "password123" }

    travel 13.hours do
      get "/admin/resources/subscriptions"
      expect(response).to redirect_to("/admin/login")
    end
  end

  it "loses access when demoted" do
    post "/admin/login", params: { phone: super_admin.phone, password: "password123" }
    super_admin.update!(role: :user)

    get "/admin/resources/subscriptions"
    expect(response).to redirect_to("/admin/login")
  end

  it "signs out" do
    post "/admin/login", params: { phone: super_admin.phone, password: "password123" }
    delete "/admin/logout"

    get "/admin/resources/subscriptions"
    expect(response).to redirect_to("/admin/login")
  end
end
