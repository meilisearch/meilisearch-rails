FROM ruby:3.1.2-slim
ENV LANG C.UTF-8

RUN apt-get update -qq && apt-get install -yq --no-install-recommends \
    build-essential \
    gnupg2 \
    less \
    git \
    telnet \
    nodejs \
    npm \
    python \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN apt-get update -qq && apt-get install -y libpq-dev
RUN npm install -g yarn

EXPOSE  3000
CMD yarn install && bundle install && rm -f tmp/pids/server.pid && bundle exec rails s -b '0.0.0.0'
