RSpec.shared_context "database setup" do
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
end