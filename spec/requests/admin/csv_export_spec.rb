require "rails_helper"

RSpec.describe "CSV export", type: :request do
  it "exports the filtered firm list with a BOM and neutralized formulas, audited" do
    admin = sign_in_admin
    create(:firm, name: "=HYPERLINK(\"http://evil\")")
    create(:firm, :pending, name: "Pending one")

    get "/admin/firms.csv", params: { status: "active" }

    expect(response.media_type).to eq("text/csv")
    expect(response.body).to start_with("﻿")
    rows = CSV.parse(response.body.delete_prefix("﻿"))
    expect(rows.size).to eq(2)
    expect(rows.last).to include("'=HYPERLINK(\"http://evil\")")
    expect(AuditEvent.last).to have_attributes(action: "firms.export", actor: admin)
    expect(AuditEvent.last.changeset["filters"]).to eq([ nil, { "status" => "active" } ])
  end

  it "exports users and subscriptions without secrets" do
    sign_in_admin
    create(:subscription)

    get "/admin/users.csv"
    expect(response.body).not_to include("password")

    get "/admin/subscriptions.csv"
    expect(CSV.parse(response.body.delete_prefix("﻿")).first).to include("رقم العملية")
  end

  it "needs the export permission" do
    staff = create(:user, role: :staff, password: "password123")
    staff.staff_permissions.create!(permission: "firms.moderate")
    sign_in_admin(staff)

    get "/admin/firms.csv"

    expect(response).to redirect_to("/admin")
    get "/admin/firms"
    expect(response.body).not_to include("تصدير CSV")
  end
end
