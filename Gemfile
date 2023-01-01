source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.3"

gem "rails", "~> 7.0.4"
gem "pg"
gem "puma", "~> 5.0"
gem "sidekiq"
gem "sprockets-rails"

gem "activeadmin"
gem "cancancan"
gem "devise"
gem "haml-rails"
gem "jquery-rails"
gem "money"
gem "simple_form"
gem "carrierwave"
# gem "bootstrap-sass"
# gem "font-awesome-rails"

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

# group :development, :test do
  # gem "rspec-rails"
  # gem "pry"
  # gem "fabrication"
  # gem "faker"
  # gem "fuubar", require: false
# end

# group :test do
  # gem "rr", "1.1.2", require: false
  # gem "timecop"
  # gem "simplecov", require: false
# end

group :production do
  gem "lograge"
end
