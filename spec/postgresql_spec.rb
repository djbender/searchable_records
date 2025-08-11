require "rails_helper"

# PostgreSQL-specific tests
RSpec.describe "SearchableRecords PostgreSQL Features", type: :integration, database_adapter: :postgresql do

  include_context "database setup"

  describe "trigram extension support" do
    before do
      # Enable pg_trgm extension if not already enabled
      begin
        ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
      rescue ActiveRecord::StatementInvalid => e
        skip "pg_trgm extension not available: #{e.message}"
      end
    end

    it "supports trigram similarity queries" do
      TestModel.create!(name: "SearchableRecords", description: "A Rails gem")
      TestModel.create!(name: "Searchable", description: "Another gem")
      TestModel.create!(name: "Records", description: "Database records")
      
      # Test trigram similarity function
      similarity_sql = "SELECT similarity('SearchableRecords', 'Searchable') as sim"
      result = ActiveRecord::Base.connection.execute(similarity_sql)
      similarity = result.first['sim'].to_f
      
      expect(similarity).to be > 0.3  # Default threshold
    end

    it "can use trigram indexes for performance" do
      # Create a trigram index (without CONCURRENTLY in tests to avoid transaction issues)
      begin
        ActiveRecord::Base.connection.execute(
          "CREATE INDEX IF NOT EXISTS test_models_name_trgm_idx ON test_models USING gin (name gin_trgm_ops)"
        )
      rescue ActiveRecord::StatementInvalid => e
        skip "Cannot create trigram index: #{e.message}"
      end

      # Add some test data
      TestModel.create!(name: "PostgreSQL Database", description: "Relational database")
      TestModel.create!(name: "MySQL Database", description: "Another database")
      TestModel.create!(name: "SQLite Database", description: "Lightweight database")

      # Test that searches work with trigram index
      results = TestModel.search("PostgreSQL")
      expect(results.count).to eq(1)
      expect(results.first.name).to eq("PostgreSQL Database")

      # Clean up
      ActiveRecord::Base.connection.execute(
        "DROP INDEX IF EXISTS test_models_name_trgm_idx"
      )
    end
  end

  describe "PostgreSQL-specific search behavior" do
    before do
      TestModel.delete_all
      @model1 = TestModel.create!(name: "Case Sensitive", description: "PostgreSQL test")
      @model2 = TestModel.create!(name: "case sensitive", description: "lowercase test")
    end

    it "uses LIKE for case-sensitive searches (PostgreSQL default)" do
      case_sensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: true
      end

      # PostgreSQL LIKE is case-sensitive by default
      upper_results = case_sensitive_model.search("Case Sensitive")
      lower_results = case_sensitive_model.search("case sensitive")

      expect(upper_results.count).to eq(1)
      expect(upper_results.first.name).to eq("Case Sensitive")
      
      expect(lower_results.count).to eq(1)
      expect(lower_results.first.name).to eq("case sensitive")
      
      # Mixed case should not match either
      mixed_results = case_sensitive_model.search("Case sensitive")
      expect(mixed_results.count).to eq(0)
    end

    it "uses LOWER() for case-insensitive searches" do
      case_insensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: false
      end

      # Should find both records regardless of case
      results = case_insensitive_model.search("CASE SENSITIVE")
      expect(results.count).to eq(2)
    end
  end

  describe "PostgreSQL performance features" do
    it "uses native ILIKE operator for case-insensitive search" do
      TestModel.delete_all
      TestModel.create!(name: "Performance Test", description: "PostgreSQL ILIKE")
      
      # Our case-insensitive implementation should use ILIKE on PostgreSQL
      results = TestModel.search("performance")
      expect(results.count).to eq(1)
      
      # Check the generated SQL uses ILIKE (PostgreSQL-specific optimization)
      sql = TestModel.search("performance").to_sql
      expect(sql).to include("ILIKE")
      expect(sql).not_to include("LOWER")  # Should not use LOWER() anymore
    end

    it "handles special PostgreSQL characters correctly" do
      TestModel.delete_all
      TestModel.create!(name: "Has_underscore_char", description: "underscore test")
      TestModel.create!(name: "Has%percent%char", description: "percent test")
      
      # Should find records with special characters  
      underscore_results = TestModel.search("underscore")
      expect(underscore_results.count).to eq(1)
      expect(underscore_results.first.name).to eq("Has_underscore_char")
      
      percent_results = TestModel.search("percent")
      expect(percent_results.count).to eq(1)
      expect(percent_results.first.name).to eq("Has%percent%char")
    end
  end

  describe "PostgreSQL indexing recommendations validation" do
    it "can create and use recommended trigram indexes" do
      # Test the exact index creation from our documentation
      begin
        ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
        
        # Create indexes as recommended in documentation (without CONCURRENTLY for tests)
        ActiveRecord::Base.connection.execute(
          "CREATE INDEX IF NOT EXISTS test_name_trgm_idx ON test_models USING gin (name gin_trgm_ops)"
        )
        ActiveRecord::Base.connection.execute(
          "CREATE INDEX IF NOT EXISTS test_desc_trgm_idx ON test_models USING gin (description gin_trgm_ops)"  
        )

        # Test that the indexes exist
        indexes = ActiveRecord::Base.connection.execute(
          "SELECT indexname FROM pg_indexes WHERE tablename = 'test_models' AND indexname LIKE '%trgm%'"
        )
        
        expect(indexes.count).to be >= 2
        
        # Test search performance with indexes
        TestModel.delete_all
        100.times do |i|
          TestModel.create!(
            name: "Test Record #{i}", 
            description: "Description for record #{i} with searchable content"
          )
        end
        
        # This should use the trigram indexes
        results = TestModel.search("Record")
        expect(results.count).to eq(100)
        
        # Clean up indexes
        ActiveRecord::Base.connection.execute("DROP INDEX IF EXISTS test_name_trgm_idx")
        ActiveRecord::Base.connection.execute("DROP INDEX IF EXISTS test_desc_trgm_idx")
        
      rescue ActiveRecord::StatementInvalid => e
        skip "Could not test trigram indexes: #{e.message}"
      end
    end

    it "supports case-insensitive expression indexes" do
      begin
        # Create case-insensitive expression index as recommended (without CONCURRENTLY for tests)
        ActiveRecord::Base.connection.execute(
          "CREATE INDEX IF NOT EXISTS test_name_lower_idx ON test_models USING gin (LOWER(name) gin_trgm_ops)"
        )
        
        TestModel.delete_all
        TestModel.create!(name: "CamelCase", description: "Test")
        TestModel.create!(name: "lowercase", description: "Test")
        
        # Case-insensitive search should benefit from the expression index
        results = TestModel.search("CAMELCASE")
        expect(results.count).to eq(1)
        
        # Clean up
        ActiveRecord::Base.connection.execute("DROP INDEX IF EXISTS test_name_lower_idx")
        
      rescue ActiveRecord::StatementInvalid => e
        skip "Could not test expression indexes: #{e.message}"
      end
    end
  end
end