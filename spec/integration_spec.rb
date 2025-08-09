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
    it "adds search class method" do
      expect(TestModel).to respond_to(:search)
    end

    it "adds searchable_fields class method" do
      expect(TestModel).to respond_to(:searchable_fields)
    end

    it "search method returns nil (no-op)" do
      expect(TestModel.search("query")).to be_nil
    end

    it "searchable_fields method returns nil (no-op)" do
      expect(TestModel.searchable_fields).to be_nil
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