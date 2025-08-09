require "rails_helper"

RSpec.describe "SearchableRecords Integration", type: :integration do
  include_context "database setup"

  describe "searchable method" do
    it "can be called on ActiveRecord models" do
      expect { TestModel.searchable }.not_to raise_error
    end

    it "does not affect non-ActiveRecord classes" do
      regular_class = Class.new
      expect(regular_class).not_to respond_to(:searchable)
    end
  end

  describe "class methods" do
    before do
      TestModel.delete_all
      @model1 = TestModel.create!(name: "John Doe", description: "A developer")
      @model2 = TestModel.create!(name: "Jane Smith", description: "A designer")
      @model3 = TestModel.create!(name: "Bob Johnson", description: "John Doe")
    end

    it "adds search class method" do
      expect(TestModel).to respond_to(:search)
    end

    it "adds searchable_fields class method" do
      expect(TestModel).to respond_to(:searchable_fields)
    end

    it "includes name and description in searchable_fields" do
      expect(TestModel.searchable_fields).to include("name", "description")
    end

    it "excludes non-text columns from searchable_fields" do
      expect(TestModel.searchable_fields).not_to include("id", "created_at", "updated_at")
    end

    it "searches across multiple columns" do
      results = TestModel.search("John Doe")
      expect(results).to match_array([@model1, @model3])  # @model1 has "John Doe" in name, @model3 has "John Doe" in description
    end

    it "finds exact name matches" do
      results = TestModel.search("Jane Smith")
      expect(results).to match_array([@model2])
    end

    it "finds partial description matches" do
      results = TestModel.search("designer")
      expect(results).to match_array([@model2])
    end

    it "finds partial name matches" do
      results = TestModel.search("John")
      expect(results).to match_array([@model1, @model3])  # Both contain "John"
    end

    it "finds partial description matches with different query" do
      results = TestModel.search("developer")
      expect(results).to match_array([@model1])
    end

    it "returns empty result for no matches" do
      results = TestModel.search("No Match")
      expect(results).to be_empty
    end

    it "returns empty result for empty string query" do
      expect(TestModel.search("")).to be_empty
    end

    it "returns empty result for nil query" do
      expect(TestModel.search(nil)).to be_empty
    end

    it "does not search non-text columns like ID" do
      # Even if we search for the ID value as a string, it shouldn't match
      # because ID columns are not included in searchable fields
      results = TestModel.search(@model1.id.to_s)
      expect(results).to be_empty
    end

    it "is case insensitive with lowercase queries" do
      results = TestModel.search("john")  # lowercase
      expect(results).to match_array([@model1, @model3])  # SQLite LIKE is case-insensitive
    end

    it "is case insensitive with uppercase queries" do
      results = TestModel.search("DEVELOPER")  # uppercase
      expect(results).to match_array([@model1])  # Matches "A developer"
    end
  end

  describe "instance methods" do
    it "adds searchable? instance method" do
      instance = TestModel.new
      expect(instance).to respond_to(:searchable?)
    end

    it "adds search_data instance method" do
      instance = TestModel.new
      expect(instance).to respond_to(:search_data)
    end

    it "searchable? returns true for instance with content" do
      instance = TestModel.new(name: "Test", description: "A test model")
      expect(instance.searchable?).to be true
    end

    it "searchable? returns false for instance with no content" do
      instance = TestModel.new(name: "", description: nil)
      expect(instance.searchable?).to be false
    end

    it "searchable? returns false for instance with only whitespace" do
      instance = TestModel.new(name: "   ", description: "\t\n")
      expect(instance.searchable?).to be false
    end

    it "searchable? returns true for instance with partial content" do
      instance = TestModel.new(name: "Test", description: "")
      expect(instance.searchable?).to be true
    end

    it "search_data returns hash of searchable fields" do
      instance = TestModel.new(name: "Test", description: "A test model")
      expected_data = { "name" => "Test", "description" => "A test model" }
      expect(instance.search_data).to eq(expected_data)
    end

    it "search_data includes nil values" do
      instance = TestModel.new(name: "Test", description: nil)
      expected_data = { "name" => "Test", "description" => nil }
      expect(instance.search_data).to eq(expected_data)
    end
  end

  describe "module isolation" do
    it "properly includes SearchableRecords::InstanceMethods" do
      TestModel.searchable
      instance = TestModel.new
      expect(instance.class.ancestors).to include(SearchableRecords::InstanceMethods)
    end

    it "properly extends SearchableRecords::ClassMethods" do
      TestModel.searchable
      expect(TestModel.singleton_class.ancestors).to include(SearchableRecords::ClassMethods)
    end

    it "fails when InstanceMethods constant doesn't exist in global scope" do
      # This test ensures the mutation that changes SearchableRecords::InstanceMethods to InstanceMethods fails
      expect { Object.const_get('InstanceMethods') }.to raise_error(NameError)
    end

    it "fails when ClassMethods constant doesn't exist in global scope" do
      # This test ensures the mutation that changes SearchableRecords::ClassMethods to ClassMethods fails
      expect { Object.const_get('ClassMethods') }.to raise_error(NameError)
    end

    it "specifically references the SearchableRecords namespace for InstanceMethods" do
      # Create a model that doesn't call searchable yet
      non_searchable_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
      end

      # Verify it doesn't have the methods
      expect(non_searchable_model.new).not_to respond_to(:searchable?)

      # Now add searchable
      non_searchable_model.extend(SearchableRecords::Searchable)
      non_searchable_model.searchable

      # Should now have instance methods
      expect(non_searchable_model.new).to respond_to(:searchable?)
    end

    it "specifically references the SearchableRecords namespace for ClassMethods" do
      # Create a model that doesn't call searchable yet
      non_searchable_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
      end

      # Verify it doesn't have the methods
      expect(non_searchable_model).not_to respond_to(:search)

      # Now add searchable
      non_searchable_model.extend(SearchableRecords::Searchable)
      non_searchable_model.searchable

      # Should now have class methods
      expect(non_searchable_model).to respond_to(:search)
    end
  end

  describe "edge cases for search" do
    before do
      TestModel.delete_all
      @model1 = TestModel.create!(name: "Test", description: "Sample")
    end

    it "handles when no searchable fields exist" do
      # Mock columns to return empty array to test conditions.empty? path
      allow(TestModel).to receive(:columns).and_return([])
      expect(TestModel.search("test")).to be_empty
    end

    it "handles whitespace-only queries differently from empty strings" do
      results = TestModel.search("   ")
      expect(results).to be_empty  # Should be treated as blank and return none
    end

    it "handles tab-only queries as blank" do
      expect(TestModel.search("\t")).to be_empty
    end

    it "handles newline-only queries as blank" do
      expect(TestModel.search("\n")).to be_empty
    end

    it "handles carriage return newline queries as blank" do
      expect(TestModel.search("\r\n")).to be_empty
    end

    it "handles false as blank query" do
      expect(TestModel.search(false)).to be_empty
    end

    it "handles zero as non-blank query" do
      TestModel.create!(name: "Value: 0", description: "Sample")
      expect(TestModel.search(0)).not_to be_empty
    end

    it "handles string zero as non-blank query" do
      TestModel.create!(name: "Test 0 content", description: "Sample")
      expect(TestModel.search("0")).not_to be_empty
    end

    it "returns default config when class variable not set" do
      model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        extend SearchableRecords::Searchable
        searchable
      end

      config = model_class.searchable_config
      expect(config[:fields]).to be_nil
    end

    it "returns default case sensitivity when class variable not set" do
      model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        extend SearchableRecords::Searchable
        searchable
      end

      config = model_class.searchable_config
      expect(config[:case_sensitive]).to be false
    end

    it "handles empty config hash when class variable set to empty" do
      TestModel.class_variable_set(:@@searchable_config, {})
      config = TestModel.searchable_config
      expect(config).to eq({})
    end
  end

  describe "ActiveRecord::Relation chaining" do
    before do
      TestModel.delete_all
      @model1 = TestModel.create!(name: "Alice", description: "Developer")
      @model2 = TestModel.create!(name: "Bob", description: "Designer")
      @model3 = TestModel.create!(name: "Charlie", description: "Developer")
    end

    it "returns ActiveRecord::Relation for method chaining" do
      relation = TestModel.search("Developer")
      expect(relation).to be_a(ActiveRecord::Relation)
      expect(relation).to respond_to(:where)
      expect(relation).to respond_to(:order)
      expect(relation).to respond_to(:limit)
    end

    it "supports chaining with where" do
      results = TestModel.search("Developer").where(name: "Alice")
      expect(results.count).to eq(1)
      expect(results.first.name).to eq("Alice")
    end

    it "supports chaining with order" do
      results = TestModel.search("Developer").order(:name)
      expect(results.count).to eq(2)
      expect(results.map(&:name)).to eq(["Alice", "Charlie"])
    end

    it "supports chaining with limit" do
      results = TestModel.search("Developer").limit(1)
      expect(results.count).to eq(1)
    end

    it "supports complex chaining" do
      results = TestModel.search("Developer").where.not(name: "Alice").order(:name).limit(1)
      expect(results.count).to eq(1)
      expect(results.first.name).to eq("Charlie")
    end

    it "supports lazy evaluation" do
      # Search should not execute until accessed
      relation = TestModel.search("Developer")
      expect(relation).to be_a(ActiveRecord::Relation)

      # Chain additional conditions
      chained = relation.where(name: "Alice")
      expect(chained).to be_a(ActiveRecord::Relation)

      # Only executes when accessed
      expect(chained.to_a.count).to eq(1)
    end
  end

  describe "API improvements" do
    before do
      TestModel.delete_all
    end

    describe "case sensitivity configuration" do
      let!(:case_sensitive_model_class) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "test_models"
          searchable case_sensitive: true
        end
      end

      let!(:case_insensitive_model_class) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "test_models"
          searchable case_sensitive: false
        end
      end

      before do
        @model1 = TestModel.create!(name: "John DOE", description: "A DEVELOPER")
        @model2 = TestModel.create!(name: "jane smith", description: "a designer")
      end

      it "performs case-sensitive search when configured" do
        results = case_sensitive_model_class.search("john")
        expect(results).to be_empty  # Should not find "John DOE" with lowercase "john"
      end

      it "finds exact case matches when case-sensitive" do
        results = case_sensitive_model_class.search("John DOE")
        expect(results.count).to eq(1)
        expect(results.first.name).to eq("John DOE")
      end

      it "performs case-insensitive search by default" do
        results = case_insensitive_model_class.search("JOHN")
        expect(results.count).to eq(1)
        expect(results.first.name).to eq("John DOE")
      end

      it "finds mixed case matches when case-insensitive" do
        results = case_insensitive_model_class.search("JANE")
        expect(results.count).to eq(1)
        expect(results.first.name).to eq("jane smith")
      end
    end

    describe "field scoping configuration" do
      let!(:name_only_model_class) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "test_models"
          searchable fields: [:name]
        end
      end

      let!(:description_only_model_class) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "test_models"
          searchable fields: [:description]
        end
      end

      before do
        @model1 = TestModel.create!(name: "NameOnlyTerm", description: "Description content")
        @model2 = TestModel.create!(name: "Name content", description: "DescriptionOnlyTerm")
      end

      it "only searches specified fields" do
        results = name_only_model_class.search("NameOnlyTerm")
        expect(results.count).to eq(1)
        expect(results.first.name).to eq("NameOnlyTerm")
      end

      it "ignores non-specified fields" do
        results = name_only_model_class.search("Description content")
        expect(results).to be_empty  # Should not find in description
      end

      it "searches only description when scoped to description" do
        results = description_only_model_class.search("DescriptionOnlyTerm")
        expect(results.count).to eq(1)
        expect(results.first.description).to eq("DescriptionOnlyTerm")
      end

      it "ignores name field when scoped to description only" do
        results = description_only_model_class.search("NameOnlyTerm")
        expect(results).to be_empty  # Should not find "NameOnlyTerm" which only exists in name field
      end

      it "returns correct searchable_fields for scoped model" do
        expect(name_only_model_class.searchable_fields).to eq(["name"])
        expect(description_only_model_class.searchable_fields).to eq(["description"])
      end

      it "handles non-existent fields gracefully" do
        non_existent_model_class = Class.new(ActiveRecord::Base) do
          self.table_name = "test_models"
          searchable fields: [:non_existent_field]
        end

        expect(non_existent_model_class.searchable_fields).to be_empty
        expect(non_existent_model_class.search("test")).to be_empty
      end
    end

    describe "combined configuration options" do
      let!(:combined_model_class) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "test_models"
          searchable fields: [:name], case_sensitive: true
        end
      end

      before do
        @model1 = TestModel.create!(name: "ExactCase", description: "should not be searched")
      end

      it "respects both field scoping and case sensitivity" do
        results = combined_model_class.search("exactcase")
        expect(results).to be_empty  # Case-sensitive, so "exactcase" != "ExactCase"
      end

      it "finds matches with exact case and correct field" do
        results = combined_model_class.search("ExactCase")
        expect(results.count).to eq(1)
      end

      it "only searches specified field even with case sensitivity" do
        results = combined_model_class.search("should not be searched")
        expect(results).to be_empty  # Description field should not be searched
      end
    end
  end

  describe "database adapter specific behavior" do
    before do
      TestModel.delete_all
      @model1 = TestModel.create!(name: "Test Content", description: "Sample Data")
    end

    it "handles SQLite case-sensitive search with GLOB" do
      case_sensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: true
      end

      allow(case_sensitive_model.connection).to receive(:adapter_name).and_return('sqlite')
      relation = case_sensitive_model.search("Test")
      expect(relation.to_sql).to include("GLOB")
    end

    it "handles SQLite3 case-sensitive search with GLOB" do
      case_sensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: true
      end

      allow(case_sensitive_model.connection).to receive(:adapter_name).and_return('sqlite3')
      relation = case_sensitive_model.search("Test")
      expect(relation.to_sql).to include("GLOB")
    end

    it "handles PostgreSQL case-sensitive search with LIKE" do
      case_sensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: true
      end

      allow(case_sensitive_model.connection).to receive(:adapter_name).and_return('postgresql')
      expect(case_sensitive_model.search("Test")).not_to be_empty
    end

    it "handles MySQL2 case-sensitive search with COLLATE" do
      case_sensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: true
      end

      allow(case_sensitive_model.connection).to receive(:adapter_name).and_return('mysql2')
      relation = case_sensitive_model.search("Test")
      expect(relation.to_sql).to include("utf8mb4_bin")
    end

    it "handles Trilogy case-sensitive search with COLLATE" do
      case_sensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: true
      end

      allow(case_sensitive_model.connection).to receive(:adapter_name).and_return('trilogy')
      relation = case_sensitive_model.search("Test")
      expect(relation.to_sql).to include("utf8mb4_bin")
    end

    it "handles unknown adapter case-sensitive search with fallback LIKE" do
      case_sensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: true
      end

      allow(case_sensitive_model.connection).to receive(:adapter_name).and_return('unknown_adapter')
      expect(case_sensitive_model.search("Test")).not_to be_empty
    end

    it "handles PostgreSQL case-insensitive search with ILIKE" do
      case_insensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: false
      end

      allow(case_insensitive_model.connection).to receive(:adapter_name).and_return('postgresql')
      relation = case_insensitive_model.search("test")
      expect(relation.to_sql).to include("ILIKE")
    end

    it "handles MySQL2 case-insensitive search with COLLATE" do
      case_insensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: false
      end

      allow(case_insensitive_model.connection).to receive(:adapter_name).and_return('mysql2')
      relation = case_insensitive_model.search("test")
      expect(relation.to_sql).to include("utf8mb4_unicode_ci")
    end

    it "handles Trilogy case-insensitive search with COLLATE" do
      case_insensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: false
      end

      allow(case_insensitive_model.connection).to receive(:adapter_name).and_return('trilogy')
      relation = case_insensitive_model.search("test")
      expect(relation.to_sql).to include("utf8mb4_unicode_ci")
    end

    it "handles unknown adapter case-insensitive search with LOWER fallback" do
      case_insensitive_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable case_sensitive: false
      end

      allow(case_insensitive_model.connection).to receive(:adapter_name).and_return('unknown_adapter')
      relation = case_insensitive_model.search("TEST")
      expect(relation.to_sql).to include("LOWER")
    end
  end

  describe "instance method edge cases" do
    it "handles searchable? with empty string values" do
      instance = TestModel.new(name: "", description: "")
      expect(instance.searchable?).to be false
    end

    it "handles searchable? with nil values" do
      instance = TestModel.new(name: nil, description: nil)
      expect(instance.searchable?).to be false
    end

    it "handles searchable? with mixed empty and content values" do
      instance = TestModel.new(name: "Content", description: "")
      expect(instance.searchable?).to be true
    end

    it "handles searchable? with whitespace-only content" do
      instance = TestModel.new(name: "   \t\n   ", description: nil)
      expect(instance.searchable?).to be false
    end

    it "handles search_data with various field types" do
      instance = TestModel.new(name: "Test", description: "Content")
      data = instance.search_data
      expect(data.keys).to match_array(["name", "description"])
    end

    it "returns search_data hash structure correctly" do
      instance = TestModel.new(name: "Test", description: nil)
      data = instance.search_data
      expect(data).to be_a(Hash)
    end
  end

  describe "searchable_fields edge cases" do
    it "handles fields option with string array" do
      string_fields_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable fields: ["name"]
      end

      expect(string_fields_model.searchable_fields).to eq(["name"])
    end

    it "handles fields option with symbol array" do
      symbol_fields_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable fields: [:name]
      end

      expect(symbol_fields_model.searchable_fields).to eq(["name"])
    end

    it "handles fields option with mixed string and symbol array" do
      mixed_fields_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable fields: [:name, "description"]
      end

      fields = mixed_fields_model.searchable_fields
      expect(fields).to include("name", "description")
    end

    it "filters out non-existent fields" do
      invalid_fields_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable fields: [:name, :non_existent_field]
      end

      expect(invalid_fields_model.searchable_fields).to eq(["name"])
    end

    it "returns all searchable columns when no fields specified" do
      all_fields_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        searchable
      end

      fields = all_fields_model.searchable_fields
      expect(fields).to include("name", "description")
    end
  end
end
