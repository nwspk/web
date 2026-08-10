source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.3"

gem "rails", "~> 7.0.4"
gem "pg"
gem "puma", "~> 5.6.9"
gem "sidekiq"
gem "sprockets-rails"

gem "activeadmin"
gem "cancancan"
gem "devise"
gem "haml-rails"
gem "jquery-rails"
gem "money"
gem "simple_form"
gem "carrierwave", "~> 2.2.7"

gem "icalendar"
gem "kramdown"
gem "stripe"

group :development do
  gem "letter_opener"
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop", require: false
  gem "web-console"
  # gem "brakeman", require: false
  # gem "rack-mini-profiler"
end

group :development, :test do
  gem "rspec-rails"
  gem "pry"
  gem "fabrication"
  gem "faker"
  gem "fuubar", require: false
end

group :test do
  gem "timecop"
  gem "simplecov", require: false
  gem "stripe-ruby-mock", require: "stripe_mock"
end

group :production do
  gem "lograge"
end
