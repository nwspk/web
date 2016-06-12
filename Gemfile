source 'https://rubygems.org'

gem 'rails', '4.2.5.1'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'coffee-rails', '~> 4.1.0'
gem 'therubyracer', platforms: :ruby
gem 'jquery-rails'
gem 'jbuilder', '~> 2.0'
gem 'sdoc', '~> 0.4.0', group: :doc
gem 'puma'

gem 'devise'
gem 'devise_invitable'
gem 'simple_form'
gem 'haml-rails'
gem 'bootstrap-sass'
gem 'font-awesome-rails'
gem 'money'
gem 'chronic'
gem 'activeadmin', '~> 1.0.0.pre1'
gem 'cancancan', '~> 1.10'

gem 'omniauth-facebook'
gem 'omniauth-twitter'
gem 'twitter'
gem 'koala', '~> 2.0'
gem 'stripe'
gem 'louvian_ruby'
gem 'terminal-table'
gem 'resque', "~> 1.22.0"
gem 'icalendar'
gem 'kramdown'
gem 'best_in_place', '~> 3.0.1'
gem 'dotenv-rails'

group :development do
  gem 'web-console', '~> 2.0'
  gem 'better_errors'
  gem 'quiet_assets'
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
  gem 'rack-mini-profiler'
  gem 'letter_opener'
end

group :development, :test do
  gem 'sqlite3'
  gem 'rspec-rails'
  gem 'pry'
  gem 'fabrication'
  gem 'faker'
  gem 'rubocop', require: false
  gem 'fuubar', require: false
end

group :test do
  gem 'rr', require: false
  gem 'stripe-ruby-mock', '~> 2.1.1', :require => 'stripe_mock'
  gem 'timecop'
  gem 'simplecov', require: false
end

group :production do
  gem 'pg'
  gem 'rails_12factor'
end

ruby "2.2.4"
