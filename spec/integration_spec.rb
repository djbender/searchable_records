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
    let(:instance) { TestModel.new(name: "Test", description: "A test model") }

    it "adds searchable? instance method" do
      expect(instance).to respond_to(:searchable?)
    end

    it "adds search_data instance method" do
      expect(instance).to respond_to(:search_data)
    end

    it "searchable? returns true" do
      expect(instance.searchable?).to be true
    end

    it "search_data returns nil (no-op)" do
      expect(instance.search_data).to be_nil
    end
  end
end
