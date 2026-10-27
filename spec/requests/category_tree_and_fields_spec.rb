require "rails_helper"

RSpec.describe "Category tree and custom fields", type: :request do
  let(:health) { create(:category, name: "صحة", position: 1) }
  let(:pharmacies) { create(:category, name: "صيدليات", parent: health) }

  describe "sub-categories" do
    it "lists top-level categories by default, as older apps expect, and children on request" do
      pharmacies

      get "/api/v1/categories"
      expect(json["data"].map { _1["name"] }).to eq([ "صحة" ])
      expect(json["data"].first).to include("children_count" => 1, "parent_id" => nil)

      get "/api/v1/categories", params: { parent_id: health.id }
      expect(json["data"].map { _1["name"] }).to eq([ "صيدليات" ])
    end

    it "lists a parent's firms together with its children's" do
      create(:firm, name: "Direct", category: health)
      create(:firm, name: "Child", category: pharmacies)
      create(:firm, name: "Elsewhere")

      get "/api/v1/categories/#{health.id}/firms"

      expect(json["data"].map { _1["name"] }).to contain_exactly("Direct", "Child")
    end

    it "allows one level only" do
      grandchild = build(:category, parent: pharmacies)
      expect(grandchild).not_to be_valid

      health.parent = create(:category)
      pharmacies # health now has a child
      expect(health).not_to be_valid
    end
  end

  describe "custom fields" do
    before do
      pharmacies.fields.create!(key: "open_24h", label: "يعمل ٢٤ ساعة", kind: :boolean, required: true)
      pharmacies.fields.create!(key: "delivery", label: "التوصيل", kind: :choice, options: %w[مجاني بأجر])
    end

    let(:owner) { create(:user, :subscribed) }

    it "casts, validates and serves values with labels, dropping unknown keys" do
      post "/api/v1/firms", params: { firm: { name: "Nour", category_id: pharmacies.id,
                                              custom_fields: { open_24h: "true", delivery: "مجاني", hacked: "x" } } },
                            headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      expect(Firm.last.custom_fields).to eq("open_24h" => true, "delivery" => "مجاني")
      expect(json["data"]["custom_fields"]).to eq([
        { "key" => "open_24h", "label" => "يعمل ٢٤ ساعة", "value" => true },
        { "key" => "delivery", "label" => "التوصيل", "value" => "مجاني" }
      ])
    end

    it "rejects a missing required field and an unknown option" do
      post "/api/v1/firms", params: { firm: { name: "Nour", category_id: pharmacies.id, custom_fields: { delivery: "طيران" } } },
                            headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["details"]["custom_fields"].join).to include("مطلوب", "اختيار غير موجود")
    end

    it "keeps a removed field's value stored but stops showing it" do
      firm = create(:firm, category: pharmacies, custom_fields: { "open_24h" => true, "delivery" => "مجاني" })
      pharmacies.fields.find_by(key: "delivery").destroy!

      get "/api/v1/firms/#{firm.id}"

      expect(json["data"]["custom_fields"].map { _1["key"] }).to eq([ "open_24h" ])
      expect(firm.reload.custom_fields).to include("delivery" => "مجاني")
    end

    it "publishes the field definitions on the category" do
      get "/api/v1/categories", params: { parent_id: health.id }

      expect(json["data"].first["fields"].map { _1["key"] }).to eq(%w[open_24h delivery])
    end

    it "is managed from the dashboard" do
      sign_in_admin

      post "/admin/categories/#{health.id}/fields",
           params: { category_field: { key: "speciality", label: "التخصص", kind: "choice", options: "باطنة، أطفال" } }

      expect(health.fields.last).to have_attributes(key: "speciality", options: %w[باطنة أطفال])
      get "/admin/categories/#{health.id}/edit"
      expect(response.body).to include("speciality")
    end
  end
end
