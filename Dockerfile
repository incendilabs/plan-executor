FROM ruby:3.2.7

WORKDIR /app
COPY . ./
RUN gem install bundler -v 2.4.19
RUN bundle install

ENTRYPOINT []
