require "rails_helper"

RSpec.describe "Settings and app config", type: :request do
  it "serves defaults to the app before anything is set" do
    get "/api/v1/app_config"

    expect(response.headers["Cache-Control"]).to include("public")
    expect(json["data"]).to eq("support_phone" => nil, "min_android_version" => 1, "latest_android_version" => 1, "banner" => nil)
  end

  it "lets a super admin change values, typed and audited" do
    sign_in_admin

    patch "/admin/settings", params: { settings: { min_android_version: "12", banner: " صيانة الليلة ", support_phone: "" } }

    expect(response).to redirect_to("/admin/settings/edit")
    get "/api/v1/app_config"
    expect(json["data"]).to include("min_android_version" => 12, "banner" => "صيانة الليلة", "support_phone" => nil)
    expect(AuditEvent.where(action: "setting.update").count).to eq(2)
  end

  it "rejects a non-numeric version" do
    sign_in_admin

    patch "/admin/settings", params: { settings: { min_android_version: "abc" } }

    expect(flash[:alert]).to be_present
    expect(Setting.get(:min_android_version)).to eq(1)
  end

  it "is closed to staff" do
    staff = create(:user, role: :staff, password: "password123")
    staff.staff_permissions.create!(permission: "users.manage")
    sign_in_admin(staff)

    get "/admin/settings/edit"

    expect(response).to redirect_to("/admin")
  end
end
