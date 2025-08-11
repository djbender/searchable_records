require "spec_helper"

ENV["RAILS_ENV"] = "test"

# Intercept and filter warnings before Rails loads
original_warn = Warning.method(:warn)
IGNORED_WARNINGS = [
  "assigned but unused variable - testEof",  # mail gem warnings
  "benchmark.rb:.*: warning: too many arguments for format string"  # benchmark gem warnings
].freeze

Warning.define_singleton_method(:warn) do |message|
  unless IGNORED_WARNINGS.any? { |ignored| message.match?(ignored) }
    original_warn.call(message)
  end
end

require File.expand_path("dummy/config/environment", __dir__)

require "rspec/rails"

# Load support files
Dir[File.join(__dir__, "support", "**", "*.rb")].sort.each { |f| require f }

RSpec.configure do |config|
  config.fixture_paths = ["#{::Rails.root}/spec/fixtures"]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # Define custom :integration type that aliases to :model
  config.define_derived_metadata(type: :integration) do |metadata|
    metadata[:type] = :model
  end

  # Filter tests based on database adapter
  current_adapter = ENV['DATABASE_ADAPTER']&.to_sym || :sqlite3
  
  # Exclude tests that don't match the current database adapter
  config.filter_run_excluding database_adapter: ->(adapter) {
    if adapter.is_a?(Array)
      !adapter.include?(current_adapter)
    else
      adapter != current_adapter
    end
  }

  # Suppress ActiveRecord migration logging
  config.before(:suite) do
    ActiveRecord::Migration.verbose = false
    
    # Create database if needed
    DatabaseAdapter.create_database_if_needed
  end
  
  config.after(:suite) do
    # Clean up database if in CI or requested
    if ENV['CI']
      DatabaseAdapter.drop_database_if_needed
    end
  end
end

