require "rails_helper"
require_relative "../../tools/performance"

RSpec.describe SearchableRecords::Performance, type: :integration do
  include_context "database setup"

  before do
    TestModel.delete_all
    # Create test data for performance testing
    10.times do |i|
      TestModel.create!(
        name: "Test User #{i}",
        description: "Description for user #{i} with searchable content"
      )
    end
  end

  describe ".benchmark_search" do
    it "runs benchmark without errors" do
      expect {
        capture_stdout do
          SearchableRecords::Performance.benchmark_search(TestModel, "User", iterations: 5)
        end
      }.not_to raise_error
    end

    it "includes performance metrics" do
      output = capture_stdout do
        SearchableRecords::Performance.benchmark_search(TestModel, "User", iterations: 5)
      end

      expect(output).to include("Benchmarking search performance")
      expect(output).to include("Search execution:")
      expect(output).to include("Search + count:")
      expect(output).to include("TestModel")
    end
  end

  describe ".explain_search" do
    it "generates query explanation without errors" do
      expect {
        capture_stdout do
          SearchableRecords::Performance.explain_search(TestModel, "User")
        end
      }.not_to raise_error
    end

    it "shows SQL and database information" do
      output = capture_stdout do
        SearchableRecords::Performance.explain_search(TestModel, "User")
      end

      expect(output).to include("Query Analysis")
      expect(output).to include("Generated SQL:")
      expect(output).to include("TestModel")
    end

    it "includes database-specific query plan" do
      output = capture_stdout do
        SearchableRecords::Performance.explain_search(TestModel, "User")
      end

      # Should include database-specific explain output
      case ENV['DATABASE_ADAPTER']
      when 'postgresql'
        expect(output).to include("PostgreSQL Execution Plan:")
      when 'mysql2'
        expect(output).to include("MySQL Execution Plan:")
      else
        expect(output).to include("SQLite Query Plan:")
      end
    end
  end

  describe ".compare_strategies" do
    it "compares different search strategies" do
      expect {
        capture_stdout do
          SearchableRecords::Performance.compare_strategies(TestModel, "User", iterations: 5)
        end
      }.not_to raise_error
    end

    it "includes multiple search approaches" do
      output = capture_stdout do
        SearchableRecords::Performance.compare_strategies(TestModel, "User", iterations: 5)
      end

      expect(output).to include("SearchableRecords:")
      expect(output).to include("Manual LIKE:")
      expect(output).to include("Raw SQL:")
    end
  end

  describe ".analyze_memory_usage" do
    it "analyzes memory usage without errors" do
      expect {
        capture_stdout do
          SearchableRecords::Performance.analyze_memory_usage(TestModel, "User", record_count: 5)
        end
      }.not_to raise_error
    end

    it "reports memory statistics" do
      output = capture_stdout do
        SearchableRecords::Performance.analyze_memory_usage(TestModel, "User", record_count: 5)
      end

      expect(output).to include("Memory usage analysis")
      expect(output).to include("Memory usage:")
      expect(output).to include("Before:")
      expect(output).to include("After:")
    end
  end

  describe "database-specific behavior" do
    it "handles PostgreSQL explain format" do
      skip "PostgreSQL-specific test" unless ENV['DATABASE_ADAPTER'] == 'postgresql'

      output = capture_stdout do
        SearchableRecords::Performance.explain_search(TestModel, "User")
      end

      expect(output).to include("PostgreSQL Execution Plan:")
    end

    it "handles SQLite explain format" do
      skip "SQLite-specific test" unless ENV['DATABASE_ADAPTER'] == 'sqlite3' || ENV['DATABASE_ADAPTER'].nil?

      output = capture_stdout do
        SearchableRecords::Performance.explain_search(TestModel, "User")
      end

      expect(output).to include("SQLite Query Plan:")
    end
  end

  describe "error handling" do
    it "gracefully handles models without search capability" do
      non_searchable_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        # Don't add searchable
      end

      expect {
        capture_stdout do
          SearchableRecords::Performance.benchmark_search(non_searchable_model, "test")
        end
      }.not_to raise_error
    end

    it "handles database connection errors gracefully" do
      allow(TestModel.connection).to receive(:execute).and_raise(StandardError, "Connection error")

      expect {
        capture_stdout do
          SearchableRecords::Performance.explain_search(TestModel, "User")
        end
      }.not_to raise_error
    end
  end

  private

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
