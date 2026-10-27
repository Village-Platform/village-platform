require "rails_helper"

RSpec.describe "Audit trail (PaperTrail)", type: :request do
  def last_version = PaperTrail::Version.order(:id).last

  describe "from the dashboard" do
    let!(:admin) { sign_in_admin }

    it "records a firm suspension with the actor, the operation, the change and the source" do
      firm = create(:firm)

      patch "/admin/firms/#{firm.id}/suspend"

      expect(last_version).to have_attributes(whodunnit: admin.id.to_s, operation: "firm.suspend", event: "update",
                                              item_type: "Firm", item_id: firm.id, item_label: firm.name, source: "admin")
      expect(last_version.object_changes["status"]).to eq(%w[active suspended])
      expect(last_version.request_id).to be_present
    end

    it "records a delete with what the record held" do
      category = create(:category, name: "مخابز")

      delete "/admin/categories/#{category.id}"

      expect(last_version).to have_attributes(event: "destroy", operation: "category.destroy", item_label: "مخابز")
      expect(last_version.object["name"]).to eq("مخابز")
    end

    it "records nothing when the write fails" do
      firm = create(:firm)

      expect { delete "/admin/categories/#{firm.category_id}" }.not_to change(PaperTrail::Version, :count)
    end

    it "never stores the password digest, yet records a password reset" do
      user = create(:user)

      patch "/admin/users/#{user.id}", params: { user: { name: "New", password: "new-password-1" } }

      versions = PaperTrail::Version.where(item_type: "User", item_id: user.id).order(:id)
      expect(versions.pluck(:operation).last(2)).to eq(%w[user.update user.password_reset])
      expect(versions.map { |v| v.object.to_h.keys + v.object_changes.to_h.keys }.flatten).not_to include("password_digest")
    end

    it "labels a subscription approval and the role promotion it causes" do
      subscription = create(:subscription)

      patch "/admin/subscriptions/#{subscription.id}/approve"

      operations = PaperTrail::Version.where(item_type: %w[Subscription User]).order(:id).last(2).map(&:operation)
      expect(operations).to eq(%w[subscription.approve user.promote])
      expect(last_version.whodunnit).to eq(admin.id.to_s)
    end

    it "lists versions and shows a record's history" do
      firm = create(:firm)
      patch "/admin/firms/#{firm.id}/suspend"

      get "/admin/audit", params: { subject_type: "Firm" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(firm.name, "إيقاف")

      get "/admin/firms/#{firm.id}"
      expect(response.body).to include("سجل التعديلات")
    end
  end

  it "records a super admin's API change with source api" do
    super_admin = create(:user, :super_admin)
    firm = create(:firm)

    patch "/api/v1/firms/#{firm.id}", params: { firm: { status: "suspended" } }, headers: auth_headers(super_admin)

    expect(last_version).to have_attributes(whodunnit: super_admin.id.to_s, operation: "firm.update", source: "api")
  end

  it "marks writes outside a request as system" do
    firm = create(:firm)

    expect(firm.versions.last).to have_attributes(event: "create", source: "system", whodunnit: nil)
  end
end
