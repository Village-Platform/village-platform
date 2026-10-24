require "rails_helper"

RSpec.describe "Admin brand assets", type: :request do
  it "references only brand images that exist in public/" do
    sign_in_admin
    get "/admin"
    html = response.body
    css = Rails.root.join("app/views/admin/shared/_head.html.erb").read

    paths = (html + css).scan(%r{/brand/web/[\w.-]+}).uniq
    expect(paths).not_to be_empty
    paths.each do |path|
      expect(Rails.public_path.join(path.delete_prefix("/"))).to exist, "missing #{path}"
    end
  end
end
