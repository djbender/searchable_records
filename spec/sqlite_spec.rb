require "rails_helper"

# SQLite-specific tests
RSpec.describe "SearchableRecords SQLite Features", type: :integration, database_adapter: :sqlite3 do

  include_context "database setup"

  describe "SQLite-specific search behavior" do
    before do
      TestModel.delete_all
      @model1 = TestModel.create!(name: "Case Sensitive", description: "SQLite test")
      @model2 = TestModel.create!(name: "case sensitive", description: "lowercase test")
    end

    it "uses GLOB for case-sensitive searches" do
      case_sensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: true
      end

      # SQLite GLOB is case-sensitive
      upper_results = case_sensitive_model.search("Case Sensitive")
      lower_results = case_sensitive_model.search("case sensitive")

      expect(upper_results.count).to eq(1)
      expect(upper_results.first.name).to eq("Case Sensitive")
      
      expect(lower_results.count).to eq(1)
      expect(lower_results.first.name).to eq("case sensitive")
      
      # Mixed case should not match either
      mixed_results = case_sensitive_model.search("Case sensitive")
      expect(mixed_results.count).to eq(0)

      # Check that SQL uses GLOB
      sql = case_sensitive_model.search("test").to_sql
      expect(sql).to include("GLOB")
    end

    it "uses LOWER() for case-insensitive searches" do
      case_insensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: false
      end

      # Should find both records regardless of case
      results = case_insensitive_model.search("CASE SENSITIVE")
      expect(results.count).to eq(2)

      # Check that SQL uses LOWER()
      sql = case_insensitive_model.search("test").to_sql
      expect(sql).to include("LOWER(")
    end
  end

  describe "SQLite pattern matching" do
    before do
      TestModel.delete_all
    end

    it "handles GLOB pattern matching correctly" do
      # Clear any existing data first
      TestModel.delete_all
      
      TestModel.create!(name: "Test123", description: "numeric test")
      TestModel.create!(name: "TestABC", description: "alpha test")
      TestModel.create!(name: "test456", description: "lowercase numeric")
      
      case_sensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: true
      end

      # GLOB should be case-sensitive - search for "Test" should find only records starting with capital T
      upper_results = case_sensitive_model.search("Test")
      expect(upper_results.count).to be >= 2  # At least Test123 and TestABC
      
      # GLOB should be case-sensitive - search for "test" should find only records with lowercase t
      lower_results = case_sensitive_model.search("test")
      lower_names = lower_results.map(&:name)
      expect(lower_names).to include("test456")
    end

    it "handles special SQLite characters correctly" do
      TestModel.create!(name: "Has_underscore_char", description: "underscore test")
      TestModel.create!(name: "Has*asterisk*char", description: "asterisk test")
      TestModel.create!(name: "Has?question?char", description: "question test")
      
      # Should find records with special characters (GLOB handles these as literals in our implementation)
      underscore_results = TestModel.search("underscore")
      expect(underscore_results.count).to eq(1)
      expect(underscore_results.first.name).to eq("Has_underscore_char")
      
      asterisk_results = TestModel.search("asterisk")
      expect(asterisk_results.count).to eq(1)
      expect(asterisk_results.first.name).to eq("Has*asterisk*char")

      question_results = TestModel.search("question")
      expect(question_results.count).to eq(1)
      expect(question_results.first.name).to eq("Has?question?char")
    end
  end

  describe "SQLite performance characteristics" do
    it "works efficiently with in-memory database" do
      TestModel.delete_all
      # Create test data
      50.times do |i|
        TestModel.create!(
          name: "SQLite Record #{i}", 
          description: "Description for record #{i} with searchable content"
        )
      end
      
      # Test that searches work efficiently
      results = TestModel.search("Record")
      expect(results.count).to eq(50)
      
      # Test partial matches
      partial_results = TestModel.search("SQLite Record 1")
      expect(partial_results.count).to be >= 10  # Should match "1", "10", "11", etc.
    end

    it "uses optimized queries for SQLite" do
      TestModel.delete_all
      TestModel.create!(name: "Performance Test", description: "SQLite optimization")
      
      # Case-insensitive should use LOWER() on SQLite
      results = TestModel.search("performance")
      expect(results.count).to eq(1)
      
      # Check the generated SQL uses LOWER() (SQLite optimization)
      sql = TestModel.search("performance").to_sql
      expect(sql).to include("LOWER(")
      expect(sql).not_to include("ILIKE")   # ILIKE is PostgreSQL-specific
      expect(sql).not_to include("BINARY")  # BINARY is MySQL-specific
    end

    it "handles concurrent read access well" do
      TestModel.delete_all
      TestModel.create!(name: "Concurrent Test", description: "SQLite concurrency")
      
      # SQLite handles multiple readers well
      threads = []
      results_array = []
      
      5.times do
        threads << Thread.new do
          local_results = TestModel.search("Concurrent")
          results_array << local_results.count
        end
      end
      
      threads.each(&:join)
      
      # All threads should find the same result
      expect(results_array).to all(eq(1))
    end
  end

  describe "SQLite indexing and optimization" do
    it "benefits from standard SQLite indexes" do
      TestModel.delete_all
      25.times do |i|
        TestModel.create!(
          name: "Test Record #{i}", 
          description: "Description for record #{i} with searchable content"
        )
      end
      
      # This should work well with SQLite's B-tree indexes
      results = TestModel.search("Record")
      expect(results.count).to eq(25)
      
      # Test field-specific searches work
      name_only_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable fields: [:name]
      end
      
      name_results = name_only_model.search("Test Record")
      expect(name_results.count).to eq(25)
    end

    it "works with SQLite's query optimizer" do
      TestModel.delete_all
      TestModel.create!(name: "SQLite Optimizer", description: "Query optimization test")
      TestModel.create!(name: "Regular Query", description: "Standard query test")
      
      # Our gem should generate queries that SQLite's optimizer can handle well
      results = TestModel.search("Optimizer")
      expect(results.count).to eq(1)
      expect(results.first.name).to eq("SQLite Optimizer")
      
      # Test that chaining works (SQLite handles complex queries)
      chained_results = TestModel.search("Query").where("description LIKE '%test%'")
      expect(chained_results.count).to eq(2)
    end

    it "handles database constraints gracefully" do
      TestModel.delete_all
      
      # Test with empty search
      empty_results = TestModel.search("")
      expect(empty_results.count).to eq(0)
      
      # Test with nil search
      expect { TestModel.search(nil) }.not_to raise_error
      
      # Test with very long search string
      long_string = "a" * 1000
      expect { TestModel.search(long_string) }.not_to raise_error
    end
  end
end