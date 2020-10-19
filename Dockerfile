FROM ruby:2.5

WORKDIR /app
COPY . ./
RUN gem install bundler -v 2.0.2
RUN bundle install

ENTRYPOINT []