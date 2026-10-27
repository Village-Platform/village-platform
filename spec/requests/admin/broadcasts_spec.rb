require "rails_helper"

RSpec.describe "Notification composer", type: :request do
  before { sign_in_admin }

  def send_broadcast(key: "key-1", **attrs)
    post "/admin/broadcasts", params: { broadcast: { idempotency_key: key, audience: "firm_admins", title: "صيانة",
                                                     body: "التطبيق متوقف الليلة", **attrs } }
  end

  it "sends one notification to each recipient of the audience" do
    owners = create_list(:user, 2, :firm_admin)
    resident = create(:user)

    send_broadcast

    expect(response).to redirect_to("/admin/broadcasts")
    expect(Notification.broadcast.pluck(:user_id)).to match_array(owners.map(&:id))
    expect(resident.notifications).to be_empty
    expect(Broadcast.last.recipients_count).to eq(2)
    expect(Notification.last).to have_attributes(title: "صيانة", body: "التطبيق متوقف الليلة")
  end

  it "sends nothing twice on a double submit" do
    create(:user, :firm_admin)

    2.times { send_broadcast }

    expect(Broadcast.count).to eq(1)
    expect(Notification.broadcast.count).to eq(1)
  end

  it "targets subscribers whose subscription ends soon and owners in a category" do
    soon = create(:user, :firm_admin)
    create(:subscription, :current, user: soon, ends_at: 3.days.from_now)
    later = create(:user, :subscribed)
    category_firm = create(:firm)

    send_broadcast(key: "k-exp", audience: "expiring", audience_params: { days: 5 })
    expect(Notification.broadcast.pluck(:user_id)).to eq([ soon.id ])

    send_broadcast(key: "k-cat", audience: "category_owners", audience_params: { category_id: category_firm.category_id })
    expect(Broadcast.last.recipients_count).to eq(1)
    expect(later.notifications.broadcast).to be_empty
  end

  it "previews the recipient count without sending" do
    create_list(:user, 3)

    get "/admin/broadcasts/new", params: { broadcast: { audience: "everyone", title: "x", body: "y", idempotency_key: "p" } }

    expect(response.body).to include("<strong>4</strong>") # three residents and the signed-in admin
    expect(Notification.count).to eq(0)
  end

  it "re-renders the form when the audience needs a parameter" do
    send_broadcast(audience: "expiring")

    expect(response).to have_http_status(:unprocessable_content)
    expect(Broadcast.count).to eq(0)
  end
end
