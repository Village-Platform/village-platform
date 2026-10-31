require "rails_helper"

RSpec.describe "Admin devices", type: :request do
  before { sign_in_admin }

  it "supports full CRUD and assigning a device to a user" do
    user = create(:user)
    post "/admin/devices", params: {
      device: { installation_id: "install-admin", token: "token-admin", platform: "android", user_id: user.id,
                 locale: "ar", app_version: "3.0.0" }
    }

    device = Device.find_by!(installation_id: "install-admin")
    expect(response).to redirect_to("/admin/devices/#{device.id}")
    expect(device.user).to eq(user)

    get "/admin/devices"
    expect(response).to have_http_status(:ok)
    get "/admin/devices/#{device.id}/edit"
    expect(response).to have_http_status(:ok)

    patch "/admin/devices/#{device.id}", params: { device: { app_version: "3.1.0" } }
    expect(response).to redirect_to("/admin/devices/#{device.id}")
    expect(device.reload.app_version).to eq("3.1.0")

    delete "/admin/devices/#{device.id}"
    expect(response).to redirect_to("/admin/devices")
    expect(Device.exists?(device.id)).to be(false)
  end

  it "shows validation errors instead of creating an invalid device" do
    post "/admin/devices", params: { device: { installation_id: "", token: "" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(Device.count).to eq(0)
  end
end
