# SearchableRecords

[![CI](https://github.com/djbender/searchable_records/actions/workflows/ci.yml/badge.svg)](https://github.com/djbender/searchable_records/actions/workflows/ci.yml)

A Rails gem that adds substring search functionality to ActiveRecord models through a simple `searchable` class method.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'searchable_records'
```

And then execute:

    $ bundle install

## Usage

### Basic Usage

To make a model searchable, simply add the `searchable` method to your model:

```ruby
class User < ApplicationRecord
  searchable
end
```

This enables substring search across all string and text columns:

```ruby
# Search for users with "john" in any text field
User.search("john")          # Finds "John Doe", "Johnny", etc.

# Case-insensitive matching (default behavior)
User.search("JOHN")          # Same results as above

# Get list of searchable fields
User.searchable_fields       # Returns ["name", "email", "bio", ...]
```

### Advanced Configuration

#### Field Scoping

Limit search to specific columns:

```ruby
class User < ApplicationRecord
  searchable fields: [:name, :email]  # Only search name and email
end

User.search("john")  # Only searches name and email columns
```

#### Case Sensitivity

Configure case-sensitive search:

```ruby
class User < ApplicationRecord
  searchable case_sensitive: true
end

User.search("John")   # Finds "John" but not "john"
User.search("john")   # Finds "john" but not "John"
```

#### Combined Options

```ruby
class User < ApplicationRecord
  searchable fields: [:name], case_sensitive: false
end

User.search("JOHN")  # Case-insensitive search only in name field
```

## Features

- **Substring matching**: Finds partial matches within text
- **Multi-column search**: Searches all string/text columns automatically
- **Case-insensitive**: Works regardless of case (configurable)
- **Field scoping**: Limit search to specific columns
- **Multi-database support**: Works with SQLite, PostgreSQL, and MySQL
- **Database-optimized**: Uses database-specific features for best performance
- **Secure**: Uses parameterized queries to prevent SQL injection
- **Type-safe**: Only searches appropriate column types (string, text)
- **Comprehensive testing**: 33 Ruby/Rails/Database combinations tested

## Compatibility

SearchableRecords is thoroughly tested across a comprehensive compatibility matrix:

### Ruby Versions
- Ruby 3.2, 3.3, 3.4, 4.0

### Rails Versions
- **Rails 7.2.2** (bug fixes until August 2025, security until August 2026)
- **Rails 8.0.2** (latest stable)
- **Rails main** (development branch for early compatibility)

### Database Adapters
- **SQLite 3** (sqlite3 gem)
- **PostgreSQL 15+** (pg gem) with trigram extension support
- **MySQL 8.0+** (mysql2 gem) with full-text search optimization

### Testing Matrix
Our CI runs **33 test combinations** covering every supported Ruby/Rails/Database combination to ensure maximum compatibility and reliability.

## Examples

```ruby
class Article < ApplicationRecord
  searchable
end

# Find articles containing "ruby" in title or content
Article.search("ruby")

# Find articles with "2024" anywhere in text fields
Article.search("2024")

# Empty/nil queries return no results
Article.search("")           # Returns empty relation
Article.search(nil)          # Returns empty relation
```

## Performance

SearchableRecords is optimized for production use with database-specific query optimizations and comprehensive performance tools.

### Query Optimizations

SearchableRecords automatically uses the most efficient query patterns for each database:

**PostgreSQL**:
- Case-insensitive: `ILIKE '%query%'` (native PostgreSQL operator)
- Case-sensitive: `LIKE '%query%'` (PostgreSQL LIKE is case-sensitive)

**MySQL**:
- Case-insensitive: `LIKE '%query%' COLLATE utf8mb4_unicode_ci`
- Case-sensitive: `LIKE '%query%' COLLATE utf8mb4_bin`

**SQLite**:
- Case-insensitive: `LOWER(column) LIKE '%query%'` 
- Case-sensitive: `GLOB '*query*'` (SQLite-specific pattern matching)

### Performance Tools

SearchableRecords includes built-in performance analysis tools:

```ruby
# Benchmark search performance
SearchableRecords::Performance.benchmark_search(User, "john", iterations: 1000)

# Analyze query execution plan
SearchableRecords::Performance.explain_search(User, "john")

# Compare different search strategies
SearchableRecords::Performance.compare_strategies(User, "john", iterations: 100)

# Analyze memory usage
SearchableRecords::Performance.analyze_memory_usage(User, "john", record_count: 500)
```

### ActiveRecord::Relation Chaining

SearchableRecords returns proper ActiveRecord::Relation objects for full query chaining:

```ruby
# Chain with other ActiveRecord methods
User.search("developer").where(active: true).order(:name).limit(10)

# Lazy evaluation - queries only execute when needed
relation = User.search("developer")
results = relation.where(active: true).to_a  # Executes single optimized query
```

### Database Indexes

For optimal search performance, add database indexes to your searchable columns. SearchableRecords performs substring searches using `LIKE '%query%'` or `GLOB '*query*'` patterns, which require careful indexing strategy.

#### Recommended Index Types by Database

**PostgreSQL** - Use trigram indexes for fast substring searches:

```ruby
# In a migration
class AddSearchIndexesToUsers < ActiveRecord::Migration[7.0]
  def up
    # Enable the pg_trgm extension
    enable_extension 'pg_trgm'

    # Add trigram indexes for substring search performance
    add_index :users, :name, using: :gin, opclass: :gin_trgm_ops
    add_index :users, :email, using: :gin, opclass: :gin_trgm_ops
    add_index :users, :bio, using: :gin, opclass: :gin_trgm_ops
  end

  def down
    remove_index :users, :name
    remove_index :users, :email
    remove_index :users, :bio
    disable_extension 'pg_trgm'
  end
end
```

**MySQL** - Use full-text indexes for text search:

```ruby
# In a migration
class AddSearchIndexesToUsers < ActiveRecord::Migration[7.0]
  def up
    # Add full-text indexes for MySQL
    execute "ALTER TABLE users ADD FULLTEXT(name)"
    execute "ALTER TABLE users ADD FULLTEXT(email)"
    execute "ALTER TABLE users ADD FULLTEXT(bio)"

    # Or combined full-text index for multi-column searches
    execute "ALTER TABLE users ADD FULLTEXT(name, email, bio)"
  end

  def down
    execute "ALTER TABLE users DROP INDEX name"
    execute "ALTER TABLE users DROP INDEX email"
    execute "ALTER TABLE users DROP INDEX bio"
  end
end
```

**SQLite** - Standard B-tree indexes (limited substring search optimization):

```ruby
# In a migration
class AddSearchIndexesToUsers < ActiveRecord::Migration[7.0]
  def change
    # SQLite doesn't support advanced text search indexes
    # Standard indexes provide some benefit for exact matches and prefixes
    add_index :users, :name
    add_index :users, :email
    add_index :users, :bio
  end
end
```

#### Scoped Field Indexing

If you're using field scoping, only index the fields you're actually searching:

```ruby
class User < ApplicationRecord
  searchable fields: [:name, :email]  # Only searches these fields
end

# Migration - only index the searched fields
class AddSearchIndexesToUsers < ActiveRecord::Migration[7.0]
  def change
    add_index :users, :name  # Index only searchable fields
    add_index :users, :email
    # Don't index bio since it's not searched
  end
end
```

#### Performance Notes

- **Trigram indexes (PostgreSQL)** provide excellent performance for substring searches but use more storage
- **Full-text indexes (MySQL)** are highly optimized for text search but may not work with short queries
- **Standard B-tree indexes (SQLite)** provide minimal benefit for substring searches but help with exact matches
- **Case-sensitive searches** may benefit from expression indexes on `LOWER(column_name)` for case-insensitive configurations
- **Large text columns** should be indexed selectively based on actual search patterns

#### Monitoring Query Performance

Check query execution plans to verify index usage:

```sql
-- PostgreSQL
EXPLAIN ANALYZE SELECT * FROM users WHERE name LIKE '%john%';

-- MySQL
EXPLAIN SELECT * FROM users WHERE MATCH(name) AGAINST('john');

-- SQLite
EXPLAIN QUERY PLAN SELECT * FROM users WHERE name LIKE '%john%';
```

## Command-Line Tools

SearchableRecords includes command-line tools for development and testing:

### Performance Testing

Use the built-in performance testing tool:

```bash
# Show help for performance testing options
bin/performance-test help

# Run performance benchmarks
bin/performance-test benchmark

# Analyze query execution plans
bin/performance-test explain

# Compare different search strategies
bin/performance-test compare
```

### Multi-Database Testing

Test across all supported databases:

```bash
# Run tests against SQLite, PostgreSQL, and MySQL
bin/test-databases

# Test specific database only
DATABASE_ADAPTER=postgresql bin/rspec
DATABASE_ADAPTER=mysql2 bin/rspec
```

## Development

### Setup

```bash
bundle install
bin/rspec
```

### Gemfile Structure

This project contains multiple Gemfiles:

- `Gemfile` - Primary development Gemfile (Ruby 4.0+)
- `Gemfile.ruby-3.2` - Base Gemfile for CI matrix builds; CI strips the Rails line and injects matrix-specific versions

### Testing Multiple Ruby Versions

Test against all supported Ruby versions locally using Docker:

```bash
bin/test-ruby-versions              # build and test Ruby 3.2, 3.3, 3.4, 4.0
bin/test-ruby-versions --build-only # build images only

# Test single version
RUBY_VERSION=3.2 docker compose build test
RUBY_VERSION=3.2 docker compose run --rm test
```

### Testing

SearchableRecords has comprehensive test coverage with **33 test combinations** in CI:

- **Testing Framework**: RSpec with integration tests using dummy Rails app
- **Ruby Versions**: 3.2, 3.3, 3.4, 4.0
- **Rails Versions**: 7.2.2, 8.0.2, main branch
- **Database Adapters**: SQLite, PostgreSQL, MySQL

#### Local Testing Commands

```bash
# Run tests with default setup
bin/rspec

# Test all supported databases
bin/test-databases

# Test specific database adapter
DATABASE_ADAPTER=postgresql bin/rspec
DATABASE_ADAPTER=mysql2 bin/rspec

# PostgreSQL-specific features (trigram indexes, etc.)
DATABASE_ADAPTER=postgresql bin/rspec spec/postgresql_spec.rb

# Docker-based testing (includes PostgreSQL with trigram extension)
docker-compose run test
```

#### CI Matrix Coverage

Our GitHub Actions CI automatically tests all combinations:
- **9 combinations**: Rails 7.2.2 × Ruby 3.2-3.4 × 3 databases
- **12 combinations**: Rails 8.0.2 × Ruby 3.2-4.0 × 3 databases
- **12 combinations**: Rails main × Ruby 3.2-4.0 × 3 databases

### Development Workflow

1. Make changes to `lib/` files
2. Add/update tests in `spec/`
3. Run test suite with `bin/test-databases` to verify changes across databases
4. Test database-specific features with appropriate adapter

## Documentation

For detailed information, see the comprehensive documentation:

- **[Database Indexing Guide](docs/DATABASE_INDEXING.md)** - Complete guide to optimizing database indexes for search performance
- **[Performance Guide](docs/PERFORMANCE.md)** - Detailed performance optimization strategies and benchmarking

## License

The gem is available as open source under the terms of the MIT License.
