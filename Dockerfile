FROM ruby:3.0.7

WORKDIR /app
COPY . ./
RUN gem install bundler -v 2.5.13
RUN bundle install

ENTRYPOINT []