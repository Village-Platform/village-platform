source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

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
