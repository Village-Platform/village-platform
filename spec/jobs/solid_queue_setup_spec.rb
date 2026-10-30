require "rails_helper"

RSpec.describe "Solid Queue setup" do
  it "keeps its tables in the primary database" do
    expect(ActiveRecord::Base.connection.table_exists?("solid_queue_jobs")).to be(true)
  end
end
