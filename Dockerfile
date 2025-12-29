FROM ruby:4-slim

# Install system dependencies
RUN apt-get update && apt-get install --yes --no-install-recommends \
    build-essential \
    libpq-dev \
    default-libmysqlclient-dev \
    libyaml-dev \
    postgresql-client \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and gemspec for dependency resolution
COPY Gemfile* *.gemspec ./
RUN bundle install --jobs=$(nproc)

# Copy the rest of the application
COPY . .

# Default command
CMD ["bin/test-databases"]
