FROM ruby:3.2-slim

# Install dependencies and timezone data
RUN apt-get update && apt-get install -y \
    build-essential \
    libpoppler-cpp-dev \
    curl \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Set timezone to Paris
ENV TZ=Europe/Paris
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install supercronic (cron for containers)
ARG SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.29/supercronic-linux-amd64
ARG SUPERCRONIC_SHA1SUM=cd48d45c4b10f3f0bfdd3a57d054cd05ac96812b
RUN curl -fsSL "$SUPERCRONIC_URL" -o /usr/local/bin/supercronic \
    && echo "$SUPERCRONIC_SHA1SUM  /usr/local/bin/supercronic" | sha1sum -c - \
    && chmod +x /usr/local/bin/supercronic

WORKDIR /app

# Copy gemfile first to leverage Docker caching
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the rest of the application
COPY . .

# Make the script executable
RUN chmod +x /app/bin/menubot

# Copy crontab
COPY crontab /app/crontab

# Default: run cron scheduler
# Override with: docker compose run menubot run
CMD ["supercronic", "/app/crontab"]
