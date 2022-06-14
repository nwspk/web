FROM ruby:2.2.4
RUN gem install bundler -v 1.17.1

WORKDIR /app
COPY Gemfile .
COPY Gemfile.lock .

RUN bundle config build.nokogiri --use-system-libraries
RUN bundle check || bundle install

COPY . .

ENTRYPOINT ["./rails-entrypoint.sh"]
