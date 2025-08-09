require "rails_helper"

RSpec.describe "SearchableRecords Integration", type: :model do
  before(:all) do
    ActiveRecord::Schema.define do
      create_table :test_models, force: true do |t|
        t.string :name
        t.text :description
        t.timestamps
      end
    end
  end

  after(:all) do
    ActiveRecord::Schema.define do
      drop_table :test_models if ActiveRecord::Base.connection.table_exists?(:test_models)
    end
  end

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

    it "returns only string/text column names for searchable_fields" do
      expect(TestModel.searchable_fields).to include("name", "description")
      expect(TestModel.searchable_fields).not_to include("id", "created_at", "updated_at")
    end

    it "finds records with exact match in any column" do
      results = TestModel.search("John Doe")
      expect(results).to include(@model1, @model3)  # @model1 has "John Doe" in name, @model3 has "John Doe" in description
      expect(results).not_to include(@model2)
    end

    it "finds records with exact match in specific values" do
      name_results = TestModel.search("Jane Smith")
      expect(name_results).to include(@model2)
      expect(name_results).not_to include(@model1, @model3)
      
      desc_results = TestModel.search("A designer")
      expect(desc_results).to include(@model2)
      expect(desc_results).not_to include(@model1, @model3)
    end

    it "finds records with exact match in description column" do
      results = TestModel.search("A developer")
      expect(results).to include(@model1)
      expect(results).not_to include(@model2, @model3)
    end

    it "returns empty result for no matches" do
      results = TestModel.search("No Match")
      expect(results).to be_empty
    end

    it "returns empty result for blank query" do
      expect(TestModel.search("")).to be_empty
      expect(TestModel.search(nil)).to be_empty
    end

    it "does not find partial matches" do
      results = TestModel.search("John")
      expect(results).to be_empty
    end

    it "does not search non-text columns like ID" do
      # Even if we search for the ID value as a string, it shouldn't match
      # because ID columns are not included in searchable fields
      results = TestModel.search(@model1.id.to_s)
      expect(results).to be_empty
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