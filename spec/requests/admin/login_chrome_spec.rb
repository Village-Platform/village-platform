require "rails_helper"

RSpec.describe "Admin login chrome", type: :request do
  it "shows a theme-aware logo so it stays visible on the dark panel" do
    get "/admin/login"
    logo = Nokogiri::HTML(response.body).at_css(".auth-card .brand-mark")
    expect(logo).to be_present
    expect(logo.css("img").map { |img| img["src"] })
      .to contain_exactly("/brand/web/logo.png", "/brand/web/logo-light.png")
  end

  it "honours a stored dark preference" do
    sign_in_admin
    patch "/admin/theme", params: { theme: "dark" }
    delete "/admin/logout"

    get "/admin/login"
    expect(response.body).to include('data-theme="dark"')
  end
end
