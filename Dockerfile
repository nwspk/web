FROM ruby:3.1.3
RUN gem install bundler

WORKDIR /app
COPY Gemfile .
COPY Gemfile.lock .

RUN bundle config build.nokogiri --use-system-libraries
RUN bundle check || bundle install

COPY . .

ENTRYPOINT ["./rails-entrypoint.sh"]
