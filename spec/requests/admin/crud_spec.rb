require "rails_helper"

RSpec.describe "Admin CRUD", type: :request do
  let!(:admin) { sign_in_admin }

  it "creates a category and shows validation errors" do
    post "/admin/categories", params: { category: { name: "صيدليات", position: 1, active: "1" } }
    expect(response).to redirect_to("/admin/categories")
    expect(Category.last.name).to eq("صيدليات")

    post "/admin/categories", params: { category: { name: "" } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "uploads, shows and removes a category icon image" do
    post "/admin/categories", params: {
      category: { name: "مساجد", position: 1, active: "1", icon_image: fixture_file_upload("receipt.png", "image/png") }
    }
    category = Category.find_by!(name: "مساجد")
    expect(category.icon_image).to be_attached

    get "/admin/categories"
    expect(response.body).to include("cat-icon")
    get "/admin/categories/#{category.id}/edit"
    expect(response.body).to include("remove_icon_image")

    patch "/admin/categories/#{category.id}", params: { category: { name: "مساجد", remove_icon_image: "1" } }
    expect(response).to redirect_to("/admin/categories")
    expect(category.reload.icon_image).not_to be_attached
  end

  it "rejects an icon that is not an image" do
    post "/admin/categories", params: {
      category: { name: "مساجد", position: 1, icon_image: fixture_file_upload("receipt.txt", "text/plain") }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Category.exists?(name: "مساجد")).to be(false)
  end

  it "does not delete a category that has firms" do
    firm = create(:firm)

    delete "/admin/categories/#{firm.category_id}"

    expect(Category.exists?(firm.category_id)).to be(true)
    expect(flash[:alert]).to be_present
  end

  it "creates a plan with the price in EGP" do
    post "/admin/subscription_plans", params: {
      subscription_plan: { name: "شهري", price: "150.50", duration_days: 30, max_firms: 1, active: "1" }
    }

    expect(SubscriptionPlan.last.price_cents).to eq(15_050)
  end

  it "approves and suspends a firm" do
    firm = create(:firm, :pending)

    patch "/admin/firms/#{firm.id}/approve"
    expect(firm.reload).to be_active

    patch "/admin/firms/#{firm.id}/suspend"
    expect(firm.reload).to be_suspended
  end

  it "publishes an article as the signed-in admin" do
    post "/admin/articles", params: { article: { title: "خبر", body: "نص", kind: "news", published_at: Time.current } }

    expect(Article.last.author).to eq(admin)
  end

  it "updates a user's role and keeps the password when left blank" do
    user = create(:user, password: "password123")

    patch "/admin/users/#{user.id}", params: { user: { role: "firm_admin", password: "" } }

    expect(user.reload).to be_firm_admin
    expect(user.authenticate("password123")).to be_truthy
  end

  it "prevents an admin from removing their own super admin role" do
    patch "/admin/users/#{admin.id}", params: { user: { role: "user" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(admin.reload).to be_super_admin
  end
end
