FROM ruby:3.2-slim

# Install PDF dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpoppler-cpp-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy gemfile first to leverage Docker caching
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the rest of the application
COPY . .

# Make the script executable
RUN chmod +x /app/bin/menubot

# Set the entrypoint to the executable
ENTRYPOINT ["/app/bin/menubot"]