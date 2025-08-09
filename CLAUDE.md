# SearchableRecords Development Guide

## Project Overview
SearchableRecords is a Rails gem that adds searchable functionality to ActiveRecord models through a simple `searchable` class method.

## Development Setup
```bash
bundle install
bundle exec rake spec
```

## Testing
- Uses RSpec for testing framework
- Includes dummy Rails app for integration testing
- Run tests: `bundle exec rspec`
- Test coverage includes both unit tests and Rails integration

## Project Structure
- `lib/` - Main gem code
- `spec/` - Test suite
- `spec/dummy/` - Dummy Rails app for integration testing
- `searchable_records.gemspec` - Gem specification

## Key Commands
- **Test**: `bundle exec rspec`
- **Console**: `bundle exec rails console` (from spec/dummy)
- **Install locally**: `gem build searchable_records.gemspec && gem install searchable_records-*.gem`

## Development Workflow
1. Make changes to `lib/` files
2. Add/update tests in `spec/`
3. Run test suite to verify changes
4. Update version in gemspec if needed