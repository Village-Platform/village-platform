require "rails_helper"

RSpec.describe "Audit log", type: :request do
  describe "from the dashboard" do
    let!(:admin) { sign_in_admin }

    it "records a firm suspension with the actor, the change and the source" do
      firm = create(:firm)

      patch "/admin/firms/#{firm.id}/suspend"

      event = AuditEvent.last
      expect(event).to have_attributes(actor: admin, action: "firm.suspend", subject_type: "Firm",
                                       subject_id: firm.id, subject_label: firm.name, source: "admin")
      expect(event.changeset["status"]).to eq(%w[active suspended])
      expect(event.request_id).to be_present
    end

    it "records a delete with a snapshot of the deleted record" do
      category = create(:category, name: "مخابز")

      delete "/admin/categories/#{category.id}"

      event = AuditEvent.last
      expect(event.action).to eq("category.destroy")
      expect(event.changeset["name"]).to eq([ "مخابز", nil ])
    end

    it "records nothing when the write fails" do
      firm = create(:firm)

      expect { delete "/admin/categories/#{firm.category_id}" }.not_to change(AuditEvent, :count)
    end

    it "never stores the password digest" do
      user = create(:user)

      patch "/admin/users/#{user.id}", params: { user: { name: "New", password: "new-password-1" } }

      expect(AuditEvent.last.changeset.keys).to eq([ "name" ])
    end

    it "records subscription approval and the role promotion it causes" do
      subscription = create(:subscription)

      patch "/admin/subscriptions/#{subscription.id}/approve"

      expect(AuditEvent.order(:id).pluck(:action)).to eq(%w[subscription.approve user.promote])
    end

    it "lists events and shows a record's history" do
      firm = create(:firm)
      patch "/admin/firms/#{firm.id}/suspend"

      get "/admin/audit", params: { subject_type: "Firm" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(firm.name)

      get "/admin/firms/#{firm.id}"
      expect(response.body).to include("سجل التعديلات")
    end
  end

  describe "from the API" do
    it "records a super admin's firm status change with source api" do
      super_admin = create(:user, :super_admin)
      firm = create(:firm)

      patch "/api/v1/firms/#{firm.id}", params: { firm: { status: "suspended" } }, headers: auth_headers(super_admin)

      expect(AuditEvent.last).to have_attributes(actor: super_admin, action: "firm.update", source: "api")
    end
  end

  it "is append-only" do
    event = Audit.record(actor: nil, action: "firm.update", subject: create(:firm), changes: {})

    expect { event.update!(action: "x") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end
