Gem::Specification.new do |spec|
  spec.name          = "searchable_records"
  spec.version       = "0.1.0"
  spec.authors       = ["Your Name"]
  spec.email         = ["your.email@example.com"]

  spec.summary       = "Add searchable functionality to ActiveRecord models"
  spec.description   = "A Rails gem that adds a searchable class method to ActiveRecord models"
  spec.homepage      = "https://github.com/yourusername/searchable_records"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.7.0"

  spec.files = Dir.glob("lib/**/*") + %w[README.md Gemfile searchable_records.gemspec]
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 6.0"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "rails", ">= 6.0"
  spec.add_development_dependency "sqlite3", ">= 1.4"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "mutant-rspec", "~> 0.13.3"
end
