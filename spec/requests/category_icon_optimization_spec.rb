require "rails_helper"
require "rake"

RSpec.describe "Category icon optimization", type: :request do
  def icon_dimensions(category)
    category.icon_image.blob.open { |file| Vips::Image.new_from_file(file.path).then { [ _1.width, _1.height ] } }
  end

  it "shrinks an icon uploaded from the dashboard and rolls the icon URL version" do
    sign_in_admin

    post "/admin/categories", params: {
      category: { name: "مخابز", position: 1, active: "1", icon_image: fixture_file_upload("icon_large.png", "image/png") }
    }

    category = Category.find_by!(name: "مخابز")
    expect(category.icon_image.blob.content_type).to eq("image/webp")
    expect(category.icon_image.blob.byte_size).to be < file_fixture("icon_large.png").size
    expect(icon_dimensions(category)).to eq([ 512, 512 ])
    expect(category.icon_url).to include("v=#{category.icon_version}")
  end

  it "shrinks an icon uploaded through the API" do
    category = create(:category)

    patch "/api/v1/categories/#{category.id}",
          params: { category: { icon_image: fixture_file_upload("icon_large.png", "image/png") } },
          headers: auth_headers(create(:user, :super_admin))

    expect(response).to have_http_status(:ok)
    expect(category.reload.icon_image.blob.content_type).to eq("image/webp")
    expect(json["data"]["icon_url"]).to eq(category.icon_url)
  end

  it "skips an icon it has already optimized" do
    category = create(:category)
    category.icon_image.attach(io: file_fixture("receipt.png").open, filename: "receipt.png", content_type: "image/png")

    expect(Categories::OptimizeIcon.call(category)).to be(true)
    blob = category.reload.icon_image.blob
    expect(Categories::OptimizeIcon.call(category)).to be(false)
    expect(category.reload.icon_image.blob).to eq(blob)
  end

  it "backfills existing icons with a rake task that is safe to run twice" do
    category = create(:category)
    category.icon_image.attach(io: file_fixture("icon_large.png").open, filename: "icon.png", content_type: "image/png")
    Rails.application.load_tasks unless Rake::Task.task_defined?("categories:optimize_icons")

    expect { Rake::Task["categories:optimize_icons"].execute }.to output(/Optimized 1/).to_stdout
    expect { Rake::Task["categories:optimize_icons"].execute }.to output(/Optimized 0/).to_stdout
    expect(category.reload.icon_image.blob.content_type).to eq("image/webp")
  end
end
