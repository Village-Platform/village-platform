require "rails_helper"
require "active_storage/service/database_service"

RSpec.describe ActiveStorage::Service::DatabaseService do
  subject(:service) { described_class.new.tap { |s| s.name = :database } }

  let(:key) { "abc123" }
  let(:data) { "\x89PNG\r\n\x1A\n binary \\x00 data".b }

  it "uploads, reads, checks and deletes a file" do
    service.upload(key, StringIO.new(data), checksum: OpenSSL::Digest::MD5.base64digest(data))

    expect(service.exist?(key)).to be(true)
    expect(service.download(key)).to eq(data)
    expect(service.download_chunk(key, 0..3)).to eq(data.byteslice(0..3))

    service.delete(key)
    expect(service.exist?(key)).to be(false)
  end

  it "rejects a wrong checksum" do
    expect { service.upload(key, StringIO.new(data), checksum: "wrong") }
      .to raise_error(ActiveStorage::IntegrityError)
    expect(StoredFile.count).to eq(0)
  end

  it "raises when the file is missing" do
    expect { service.download("missing") }.to raise_error(ActiveStorage::FileNotFoundError)
  end

  it "deletes by prefix only" do
    service.upload("variants/a", StringIO.new("1"))
    service.upload("other", StringIO.new("2"))

    service.delete_prefixed("variants/")

    expect(StoredFile.pluck(:key)).to eq([ "other" ])
  end
end

RSpec.describe "Stored files", type: :request do
  let(:service) { ActiveStorage::Service::DatabaseService.new.tap { |s| s.name = :database } }

  before { service.upload("k1", StringIO.new("hello".b)) }

  it "serves a file with a valid signed URL" do
    url = service.url("k1", expires_in: 5.minutes, filename: ActiveStorage::Filename.new("a.png"),
                            content_type: "image/png", disposition: :inline)

    get url

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("hello")
    expect(response.media_type).to eq("image/png")
    expect(response.headers["Content-Disposition"]).to start_with("inline")
  end

  it "answers 404 for a forged token" do
    get "/files/forged/a.png"

    expect(response).to have_http_status(:not_found)
  end

  it "answers 404 after the URL expires" do
    url = service.url("k1", expires_in: 5.minutes, filename: ActiveStorage::Filename.new("a.png"),
                            content_type: "image/png", disposition: :inline)

    travel 6.minutes do
      get url
    end

    expect(response).to have_http_status(:not_found)
  end
end
