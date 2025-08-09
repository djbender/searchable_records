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
end