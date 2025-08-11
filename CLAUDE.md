# SearchableRecords Development Guide

## Project Overview
SearchableRecords is a Rails gem that adds searchable functionality to ActiveRecord models through a simple `searchable` class method.

## Development Setup
```bash
bundle install
bin/rspec
```

## Testing
SearchableRecords has comprehensive test coverage with **54 Ruby/Rails/Database combinations** in CI:

### Test Framework
- Uses RSpec for testing framework with custom `:integration` type
- Includes dummy Rails app for integration testing
- All tests follow single `expect()` per test pattern
- Shared database setup in `spec/support/database_setup.rb`

### Supported Versions
- **Ruby**: 3.0, 3.1, 3.2, 3.3, 3.4
- **Rails**: 7.1.5, 7.2.2, 8.0.2, main branch
- **Databases**: SQLite, PostgreSQL (with trigram extension), MySQL

### CI Testing Matrix
Our GitHub Actions CI tests every valid Ruby/Rails/Database combination:
- **Rails 7.1.5**: 15 combinations (Ruby 3.0-3.4 × 3 databases)
- **Rails 7.2.2**: 12 combinations (Ruby 3.1-3.4 × 3 databases)
- **Rails 8.0.2**: 9 combinations (Ruby 3.2-3.4 × 3 databases)  
- **Rails main**: 9 combinations (Ruby 3.2-3.4 × 3 databases)

### Docker Support
- PostgreSQL container includes pg_trgm extension for trigram index testing
- Docker files organized in `docker/` directory
- Run with: `docker-compose run test`

## Project Structure
- `lib/` - Main gem code (production)
  - `lib/searchable_records.rb` - Main gem file
  - `lib/searchable_records/searchable.rb` - Core functionality
- `tools/` - Development utilities (not included in production gem)
  - `tools/performance.rb` - Performance analysis tools
- `spec/` - Test suite
  - `spec/support/` - Shared test helpers
  - `spec/dummy/` - Dummy Rails app for integration testing
  - `spec/performance_spec.rb` - Performance tool tests
- `docs/` - Documentation
  - `docs/DATABASE_INDEXING.md` - Comprehensive indexing guide
  - `docs/PERFORMANCE.md` - Performance optimization guide
  - `docs/example_migrations/` - Example migration files
- `bin/` - Development scripts
  - `bin/performance-test` - Command-line performance testing
  - `bin/test-databases` - Multi-database test runner
  - `bin/mutant` - Mutation testing script
- `TODO.md` - Future enhancements and roadmap
- `searchable_records.gemspec` - Gem specification

## Key Commands
### Testing
- **Test (SQLite)**: `bin/rspec`
- **Test (PostgreSQL)**: `DATABASE_ADAPTER=postgresql bin/rspec`
- **Test (MySQL)**: `DATABASE_ADAPTER=mysql2 bin/rspec`
- **Test all databases**: `bin/test-databases`
- **PostgreSQL-only tests**: `DATABASE_ADAPTER=postgresql bin/rspec spec/postgresql_spec.rb`
- **Docker testing**: `docker-compose run test` (includes all 54 combinations)

### Development
- **Performance testing**: `bin/performance-test help`
- **Console**: `bundle exec rails console` (from spec/dummy)
- **Install locally**: `gem build searchable_records.gemspec && gem install searchable_records-*.gem`
- **CI matrix testing**: Automatically runs 54 Ruby/Rails/Database combinations on every PR

## Development Workflow
1. Make changes to `lib/` files
2. Add/update tests in `spec/`
3. Run test suite with `bin/test-databases` to verify changes across databases
4. Test database-specific features with appropriate adapter
5. Update version in gemspec if needed

## Current Features
- Substring search across string/text columns
- Configurable case sensitivity (case-sensitive or case-insensitive)
- Field scoping to search specific columns only
- Multi-database support (SQLite, PostgreSQL, MySQL)
- **Performance optimizations**:
  - PostgreSQL: Uses `ILIKE` for case-insensitive, `LIKE` for case-sensitive
  - MySQL: Uses `COLLATE` for optimal case handling
  - SQLite: Uses `GLOB` for case-sensitive, `LOWER()` for case-insensitive
- ActiveRecord::Relation chaining and lazy evaluation
- Parameterized queries for security
- ActiveRecord integration with custom class/instance methods
- **Performance tools**: Benchmarking, query explain, memory analysis
- Comprehensive database indexing documentation
- PostgreSQL trigram index support and testing

## Code standards
- Always check codecoverage.
- Do not run the mutation tests unless specifically asked and approved.
- Mutation testing available via `bin/mutant` (use with caution as it's resource intensive).
