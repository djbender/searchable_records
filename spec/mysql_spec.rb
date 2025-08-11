require "rails_helper"

# MySQL-specific tests
RSpec.describe "SearchableRecords MySQL Features", type: :integration, database_adapter: [:mysql2, :trilogy] do

  include_context "database setup"

  describe "MySQL-specific search behavior" do
    before do
      TestModel.delete_all
      @model1 = TestModel.create!(name: "Case Sensitive", description: "MySQL test")
      @model2 = TestModel.create!(name: "case sensitive", description: "lowercase test")
    end

    it "uses BINARY for case-sensitive searches" do
      case_sensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: true
      end

      # MySQL BINARY makes LIKE case-sensitive
      upper_results = case_sensitive_model.search("Case Sensitive")
      lower_results = case_sensitive_model.search("case sensitive")

      expect(upper_results.count).to eq(1)
      expect(upper_results.first.name).to eq("Case Sensitive")
      
      expect(lower_results.count).to eq(1)
      expect(lower_results.first.name).to eq("case sensitive")
      
      # Mixed case should not match either
      mixed_results = case_sensitive_model.search("Case sensitive")
      expect(mixed_results.count).to eq(0)

      # Check that SQL uses BINARY
      sql = case_sensitive_model.search("test").to_sql
      expect(sql).to include("BINARY")
    end

    it "uses default case-insensitive behavior" do
      case_insensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: false
      end

      # Should find both records regardless of case (MySQL default collation)
      results = case_insensitive_model.search("CASE SENSITIVE")
      expect(results.count).to eq(2)

      # Check that SQL uses regular LIKE (no BINARY)
      sql = case_insensitive_model.search("test").to_sql
      expect(sql).not_to include("BINARY")
      expect(sql).not_to include("LOWER(")  # Should not use LOWER() on MySQL
    end
  end

  describe "MySQL collation handling" do
    it "works with different collations" do
      TestModel.delete_all
      TestModel.create!(name: "Åpfel", description: "Unicode test")
      TestModel.create!(name: "Apple", description: "ASCII test")
      
      # Should handle Unicode characters correctly
      unicode_results = TestModel.search("Åpfel")
      expect(unicode_results.count).to eq(1)
      expect(unicode_results.first.name).to eq("Åpfel")
      
      ascii_results = TestModel.search("Apple")
      expect(ascii_results.count).to eq(1)
      expect(ascii_results.first.name).to eq("Apple")
    end

    it "handles special MySQL characters correctly" do
      TestModel.delete_all
      TestModel.create!(name: "Has_underscore_char", description: "underscore test")
      TestModel.create!(name: "Has%percent%char", description: "percent test")
      TestModel.create!(name: "Has\\backslash\\char", description: "backslash test")
      
      # Should find records with special characters  
      underscore_results = TestModel.search("underscore")
      expect(underscore_results.count).to eq(1)
      expect(underscore_results.first.name).to eq("Has_underscore_char")
      
      percent_results = TestModel.search("percent")
      expect(percent_results.count).to eq(1)
      expect(percent_results.first.name).to eq("Has%percent%char")

      backslash_results = TestModel.search("backslash")
      expect(backslash_results.count).to eq(1)
      expect(backslash_results.first.name).to eq("Has\\backslash\\char")
    end
  end

  describe "MySQL performance features" do
    it "uses optimized LIKE queries" do
      TestModel.delete_all
      TestModel.create!(name: "Performance Test", description: "MySQL optimization")
      
      # Our case-insensitive implementation should use regular LIKE on MySQL
      results = TestModel.search("performance")
      expect(results.count).to eq(1)
      
      # Check the generated SQL uses LIKE without LOWER() (MySQL optimization)
      sql = TestModel.search("performance").to_sql
      expect(sql).to include("LIKE")
      expect(sql).not_to include("LOWER(")  # Should not use LOWER() for MySQL
      expect(sql).not_to include("ILIKE")   # ILIKE is PostgreSQL-specific
    end

    it "handles large result sets efficiently" do
      TestModel.delete_all
      # Create test data
      50.times do |i|
        TestModel.create!(
          name: "MySQL Record #{i}", 
          description: "Description for record #{i} with searchable content"
        )
      end
      
      # Test that searches work efficiently
      results = TestModel.search("Record")
      expect(results.count).to eq(50)
      
      # Test partial matches
      partial_results = TestModel.search("MySQL Record 1")
      expect(partial_results.count).to be >= 10  # Should match "1", "10", "11", etc.
    end
  end

  describe "MySQL indexing recommendations validation" do
    it "benefits from standard indexes on searchable columns" do
      # Test the behavior with potential MySQL indexes
      TestModel.delete_all
      25.times do |i|
        TestModel.create!(
          name: "Test Record #{i}", 
          description: "Description for record #{i} with searchable content"
        )
      end
      
      # This should work well with MySQL's standard B-tree indexes
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

    it "works with fulltext search potential" do
      TestModel.delete_all
      TestModel.create!(name: "MySQL FullText", description: "Full text search capabilities")
      TestModel.create!(name: "Regular Text", description: "Standard text content")
      
      # Our gem should work even if MySQL FULLTEXT indexes exist
      results = TestModel.search("FullText")
      expect(results.count).to eq(1)
      expect(results.first.name).to eq("MySQL FullText")
    end
  end
end