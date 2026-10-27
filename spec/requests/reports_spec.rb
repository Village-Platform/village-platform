require "rails_helper"

RSpec.describe "Reports", type: :request do
  let(:reporter) { create(:user) }
  let(:firm) { create(:firm) }

  def report(subject_type: "firm", subject_id: firm.id, as: reporter, reason: "wrong_info")
    post "/api/v1/reports", params: { report: { subject_type:, subject_id:, reason:, note: "الرقم خطأ" } },
                            headers: auth_headers(as)
  end

  describe "POST /api/v1/reports" do
    it "files a report without hiding anything" do
      report

      expect(response).to have_http_status(:created)
      expect(json["data"]).to include("subject_type" => "firm", "subject_id" => firm.id, "status" => "open")
      expect(firm.reload).to be_active
    end

    it "accepts one open report per user per subject" do
      report
      report

      expect(response).to have_http_status(:unprocessable_content)
      expect(Report.count).to eq(1)
    end

    it "refuses subjects the reporter cannot see, unknown types and guests" do
      report(subject_id: create(:firm, :pending).id)
      expect(response).to have_http_status(:not_found)

      report(subject_type: "user", subject_id: reporter.id)
      expect(response).to have_http_status(:bad_request)

      post "/api/v1/reports", params: { report: { subject_type: "firm", subject_id: firm.id, reason: "spam" } }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "dashboard" do
    before { sign_in_admin }

    it "groups open reports by subject, most reported first" do
      quiet = create(:firm, name: "Quiet")
      noisy = create(:firm, name: "Noisy")
      create(:report, subject: quiet)
      2.times { create(:report, subject: noisy) }

      get "/admin/reports"

      expect(response.body.index("Noisy")).to be < response.body.index("Quiet")
      expect(response.body).to include("2 بلاغ")
    end

    it "resolves every open report on a firm and suspends it, audited" do
      2.times { create(:report, subject: firm) }

      patch "/admin/reports/resolve", params: { subject_type: "Firm", subject_id: firm.id, outcome: "resolved",
                                                subject_action: "suspend_firm", note: "تأكدنا" }

      expect(Report.open.count).to eq(0)
      expect(Report.resolved.pluck(:resolution_note).uniq).to eq([ "تأكدنا" ])
      expect(firm.reload).to be_suspended
      expect(PaperTrail::Version.pluck(:operation)).to include("report.resolve", "firm.suspend")
    end

    it "dismisses reports without touching the subject" do
      create(:report, subject: firm)

      patch "/admin/reports/resolve", params: { subject_type: "Firm", subject_id: firm.id, outcome: "dismissed",
                                                subject_action: "suspend_firm" }

      expect(Report.dismissed.count).to eq(1)
      expect(firm.reload).to be_active
    end

    it "refuses an action that does not fit the subject" do
      create(:report, subject: firm)

      patch "/admin/reports/resolve", params: { subject_type: "Firm", subject_id: firm.id, outcome: "resolved",
                                                subject_action: "remove_medium" }

      expect(flash[:alert]).to be_present
      expect(Report.open.count).to eq(1)
    end
  end
end
