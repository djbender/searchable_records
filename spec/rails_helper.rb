require "spec_helper"

ENV["RAILS_ENV"] = "test"

# Intercept and filter warnings before Rails loads
original_warn = Warning.method(:warn)
Warning.define_singleton_method(:warn) do |message|
  # Skip mail gem "assigned but unused variable - testEof" warnings
  unless message.include?("assigned but unused variable - testEof")
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

  # Suppress ActiveRecord migration logging
  config.before(:suite) do
    ActiveRecord::Migration.verbose = false
    
    # Create database if needed
    if ENV['DATABASE_ADAPTER'] == 'postgresql'
      RSpec.create_postgresql_database_if_needed
    elsif ENV['DATABASE_ADAPTER'] == 'mysql2'
      DatabaseAdapter.create_database_if_needed
    end
  end
  
  config.after(:suite) do
    # Clean up database if in CI or requested
    if ENV['CI']
      if ENV['DATABASE_ADAPTER'] == 'postgresql'
        RSpec.drop_postgresql_database_if_needed
      elsif ENV['DATABASE_ADAPTER'] == 'mysql2'
        DatabaseAdapter.drop_database_if_needed
      end
    end
  end
end

# Define PostgreSQL database management methods
module RSpec
  def self.create_postgresql_database_if_needed
    database_name = 'searchable_records_test'
    
    admin_config = {
      'adapter' => 'postgresql',
      'database' => 'postgres',
      'username' => ENV.fetch('POSTGRES_USER', 'postgres'),
      'password' => ENV.fetch('POSTGRES_PASSWORD', 'postgres'),
      'host' => ENV.fetch('POSTGRES_HOST', 'localhost'),
      'port' => ENV.fetch('POSTGRES_PORT', 5432)
    }
    
    begin
      ActiveRecord::Base.establish_connection(admin_config)
      ActiveRecord::Base.connection.execute("CREATE DATABASE #{database_name}")
      puts "Created PostgreSQL test database: #{database_name}"
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("already exists")
        puts "PostgreSQL test database already exists: #{database_name}"
      else
        raise e
      end
    ensure
      # Let Rails reconnect to the test database naturally
    end
  end
  
  def self.drop_postgresql_database_if_needed  
    database_name = 'searchable_records_test'
    
    admin_config = {
      'adapter' => 'postgresql',
      'database' => 'postgres',
      'username' => ENV.fetch('POSTGRES_USER', 'postgres'),
      'password' => ENV.fetch('POSTGRES_PASSWORD', 'postgres'),
      'host' => ENV.fetch('POSTGRES_HOST', 'localhost'),
      'port' => ENV.fetch('POSTGRES_PORT', 5432)
    }
    
    begin
      ActiveRecord::Base.establish_connection(admin_config)
      ActiveRecord::Base.connection.execute("DROP DATABASE IF EXISTS #{database_name}")
      puts "Dropped PostgreSQL test database: #{database_name}"
    rescue ActiveRecord::StatementInvalid => e
      puts "Error dropping PostgreSQL database: #{e.message}"
    end
  end
end
