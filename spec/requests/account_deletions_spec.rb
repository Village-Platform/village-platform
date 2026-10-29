require "rails_helper"

RSpec.describe "Account deletion page", type: :request do
  let!(:user) { create(:user, phone: "01077777777", password: "password123") }

  it "renders the public Arabic page" do
    get "/account/delete"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('dir="rtl"', "حذف الحساب")
  end

  it "deletes the account with the right phone and password" do
    post "/account/delete", params: { phone: "0107 777 7777", password: "password123" }

    expect(response).to have_http_status(:ok)
    expect(user.reload).to be_deleted
  end

  it "keeps the account on a wrong password" do
    post "/account/delete", params: { phone: "01077777777", password: "wrong-pass" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload).not_to be_deleted
  end

  it "no longer lets a deleted user log in" do
    post "/account/delete", params: { phone: "01077777777", password: "password123" }
    post "/api/v1/auth/login", params: { phone: "01077777777", password: "password123" }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
