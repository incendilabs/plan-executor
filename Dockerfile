FROM ruby:3.4.9

WORKDIR /app
COPY . ./
RUN gem install bundler -v 4.0.10
RUN bundle install

ENTRYPOINT []
