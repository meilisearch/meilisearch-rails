FROM ruby:2.6

RUN apt-get update -y && apt-get install -y nodejs

# Create a non-root user to run the app and own app-specific files
RUN adduser package

# Switch to this user
USER package

# Same was in the docker-compose.yml
WORKDIR /home/package

# Copy over the code. This honors the .dockerignore file.
COPY --chown=package . ./

RUN gem install bundler && \
  bundle install
