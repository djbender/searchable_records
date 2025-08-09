require "rails/all"

Bundler.require(*Rails.groups)
require "searchable_records"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f

    config.root = File.dirname(__FILE__) + "/.."
    config.session_store :cookie_store, key: "_dummy_session"
    config.secret_key_base = "secret"
    config.active_support.deprecation = :log
    config.eager_load = false

    # Disable logging in test environment
    config.logger = Logger.new(nil)
  end
end
