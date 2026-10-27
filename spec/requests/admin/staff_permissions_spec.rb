require "rails_helper"

RSpec.describe "Staff permissions", type: :request do
  def staff_with(*permissions)
    create(:user, role: :staff, password: "password123").tap do |user|
      permissions.each { |permission| user.staff_permissions.create!(permission:) }
    end
  end

  it "lets staff sign in and open only what they were granted" do
    sign_in_admin(staff_with("subscriptions.review"))

    get "/admin/subscriptions"
    expect(response).to have_http_status(:ok)

    get "/admin/firms"
    expect(response).to redirect_to("/admin")

    get "/admin/subscription_plans"
    expect(response).to redirect_to("/admin")

    get "/admin/audit"
    expect(response).to redirect_to("/admin")
  end

  it "hides links to pages staff cannot open" do
    sign_in_admin(staff_with("firms.moderate"))

    get "/admin"

    expect(response.body).to include("/admin/firms")
    expect(response.body).not_to include("/admin/subscription_plans")
    expect(response.body).not_to include("طلبات اشتراك تنتظر المراجعة")
  end

  it "applies a revoked permission on the next request" do
    staff = staff_with("firms.moderate")
    sign_in_admin(staff)
    staff.staff_permissions.delete_all

    get "/admin/firms"

    expect(response).to redirect_to("/admin")
  end

  it "keeps staff with users.manage away from admin accounts and admin roles" do
    sign_in_admin(staff_with("users.manage"))
    super_admin = create(:user, :super_admin)
    resident = create(:user)

    patch "/admin/users/#{super_admin.id}", params: { user: { password: "taken-over-123" } }
    expect(response).to redirect_to("/admin/users/#{super_admin.id}")
    expect(super_admin.reload.authenticate("taken-over-123")).to be(false)

    patch "/admin/users/#{resident.id}", params: { user: { role: "super_admin" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(resident.reload).to be_user

    post "/admin/users", params: { user: { name: "X", phone: "01099999999", password: "password123", role: "staff" } }
    expect(User.exists?(phone: "01099999999")).to be(false)
  end

  it "limits global search to the types staff may open" do
    sign_in_admin(staff_with("firms.moderate"))
    create(:firm, name: "Nour pharmacy")
    create(:user, name: "Nour resident")

    get "/admin/search", params: { q: "nour" }

    expect(response.parsed_body.map { _1["type"] }.uniq).to eq([ "نشاط" ])
  end

  it "lets a super admin grant and revoke permissions, audited" do
    sign_in_admin
    staff = staff_with("firms.moderate")

    patch "/admin/users/#{staff.id}/permissions", params: { permissions: %w[articles.moderate bogus] }

    expect(staff.staff_permissions.pluck(:permission)).to eq([ "articles.moderate" ])
    expect(PaperTrail::Version.where(item_type: "StaffPermission").pluck(:operation)).to include("user.grant", "user.revoke")
  end

  it "does not let staff grant permissions" do
    staff = staff_with("users.manage")
    sign_in_admin(staff)

    patch "/admin/users/#{staff.id}/permissions", params: { permissions: StaffPermission::PERMISSIONS.keys }

    expect(staff.staff_permissions.count).to eq(1)
  end
end
