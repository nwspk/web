source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.3"

gem "rails", "~> 7.0.4"
gem "sprockets-rails"
gem "puma", "~> 5.0"
gem 'pg'

gem 'jquery-rails'
gem 'devise'
gem 'simple_form'
gem 'haml-rails'
# gem 'bootstrap-sass'
# gem 'font-awesome-rails'
gem 'money'
gem 'activeadmin'
gem 'cancancan'

gem 'stripe'
# gem 'terminal-table'
gem 'sidekiq'
gem 'icalendar'
gem 'kramdown'
# gem 'google_calendar'
# gem 'mini_magick'
gem 'carrierwave'

group :development do
  gem "web-console"
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-performance', require: false
  # gem 'better_errors'
  # gem 'quiet_assets'
  # gem 'brakeman', require: false
  # gem 'bundler-audit', require: false
  # gem 'rack-mini-profiler'
  # gem 'letter_opener'
end

# group :development, :test do
  # gem 'rspec-rails'
  # gem 'pry'
  # gem 'fabrication'
  # gem 'faker'
  # gem 'fuubar', require: false
# end

# group :test do
  # gem 'rr', '1.1.2', require: false
  # gem 'timecop'
  # gem 'simplecov', require: false
# end

group :production do
  gem 'lograge'
end
