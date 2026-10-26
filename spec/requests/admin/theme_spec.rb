require "rails_helper"

RSpec.describe "Admin theme", type: :request do
  before { sign_in_admin }

  it "stores a valid preference and renders it on <html>" do
    patch "/admin/theme", params: { theme: "dark" }, headers: { "HTTP_REFERER" => "/admin/firms" }
    expect(response).to redirect_to("/admin/firms")
    get "/admin"
    expect(response.body).to include('data-theme="dark"')
  end

  it "ignores a crafted value and renders no attribute" do
    patch "/admin/theme", params: { theme: '" onload="alert(1)' }
    get "/admin"
    expect(response.body).not_to include("onload")
    expect(response.body).not_to include("data-theme")
  end

  it "falls back to the dashboard when there is no referer" do
    patch "/admin/theme", params: { theme: "light" }
    expect(response).to redirect_to("/admin")
  end

  it "renders no attribute before any choice is made" do
    get "/admin"
    expect(response.body).not_to include("data-theme")
  end

  it "honours the preference on the login page" do
    patch "/admin/theme", params: { theme: "dark" }
    delete "/admin/logout"
    get "/admin/login"
    expect(response.body).to include('data-theme="dark"')
  end
end

RSpec.describe "Admin theme without a session", type: :request do
  it "redirects to login and sets no cookie" do
    patch "/admin/theme", params: { theme: "dark" }
    expect(response).to redirect_to("/admin/login")
    expect(cookies["admin_theme"]).to be_blank
  end
end
