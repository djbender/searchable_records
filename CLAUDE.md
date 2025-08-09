# SearchableRecords Development Guide

## Project Overview
SearchableRecords is a Rails gem that adds searchable functionality to ActiveRecord models through a simple `searchable` class method.

## Development Setup
```bash
bundle install
bin/rspec
```

## Testing
- Uses RSpec for testing framework with custom `:integration` type
- Includes dummy Rails app for integration testing
- Run tests: `bin/rspec`
- Test coverage includes both unit tests and Rails integration
- All tests follow single `expect()` per test pattern
- Shared database setup in `spec/support/database_setup.rb`

## Project Structure
- `lib/` - Main gem code
  - `lib/searchable_records.rb` - Main gem file
  - `lib/searchable_records/searchable.rb` - Core functionality
- `spec/` - Test suite
  - `spec/support/` - Shared test helpers
  - `spec/dummy/` - Dummy Rails app for integration testing
- `docs/` - Documentation
  - `docs/DATABASE_INDEXING.md` - Comprehensive indexing guide
  - `docs/example_migrations/` - Example migration files
- `searchable_records.gemspec` - Gem specification

## Key Commands
- **Test (SQLite)**: `bin/rspec`
- **Test (PostgreSQL)**: `DATABASE_ADAPTER=postgresql bin/rspec`
- **Test all databases**: `bin/test-databases`
- **PostgreSQL-only tests**: `DATABASE_ADAPTER=postgresql bin/rspec spec/postgresql_spec.rb`
- **Console**: `bundle exec rails console` (from spec/dummy)
- **Install locally**: `gem build searchable_records.gemspec && gem install searchable_records-*.gem`

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
- Database-specific optimizations (GLOB for SQLite, LIKE for PostgreSQL)
- Parameterized queries for security
- ActiveRecord integration with custom class/instance methods
- Comprehensive database indexing documentation
- PostgreSQL trigram index support and testing

## Code standards
- Always check codecoverage.
- Do not run the mutation tests unless specifically asked and approved.
