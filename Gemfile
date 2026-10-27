source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "bootsnap", require: false
gem "propshaft" # asset pipeline for the admin dashboard CSS
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "image_processing", "~> 1.2"
# Media::Optimize re-encodes uploads, so libvips is needed in every environment (and in CI).
gem "ruby-vips"
# S3-compatible object storage (Cloudflare R2) for media that must not live in PostgreSQL.
gem "aws-sdk-s3", require: false

# Auth & authorization
gem "bcrypt", "~> 3.1.7"
gem "jwt", "~> 3.1"
gem "pundit", "~> 2.5"

# API helpers
gem "rack-cors"
gem "rails-i18n", "~> 8.0"
gem "dotenv-rails"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

gem "tailwindcss-rails", "~> 4.7"
