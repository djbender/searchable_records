# Performance testing and benchmarking tools for SearchableRecords
# Development/testing tool - not included in production gem

require 'benchmark'

module SearchableRecords
  module Performance
    # Benchmark search performance with different query sizes
    def self.benchmark_search(model_class, query, iterations: 1000)
      return unless model_class.respond_to?(:search)
      
      puts "🔍 Benchmarking search performance for #{model_class.name}"
      puts "Query: '#{query}' (#{iterations} iterations)"
      puts "Database: #{model_class.connection.adapter_name}"
      puts "Total records: #{model_class.count}"
      puts "Searchable fields: #{model_class.searchable_fields.join(', ')}"
      puts

      result = Benchmark.bm(20) do |x|
        x.report("Search execution:") do
          iterations.times { model_class.search(query).load }
        end
        
        x.report("Search + count:") do
          iterations.times { model_class.search(query).count }
        end
        
        x.report("Search + first:") do
          iterations.times { model_class.search(query).first }
        end
        
        x.report("Search + limit(10):") do
          iterations.times { model_class.search(query).limit(10).to_a }
        end
      end
      
      puts
      result
    end

    # Explain query execution plan
    def self.explain_search(model_class, query)
      return unless model_class.respond_to?(:search)
      
      relation = model_class.search(query)
      sql = relation.to_sql
      
      puts "🔍 Query Analysis for #{model_class.name}"
      puts "Query: '#{query}'"
      puts "Database: #{model_class.connection.adapter_name}"
      puts

      puts "Generated SQL:"
      puts "#{sql}"
      puts

      begin
        case model_class.connection.adapter_name.downcase
        when 'postgresql'
          explain_postgresql(model_class, relation)
        when 'mysql2', 'trilogy'
          explain_mysql(model_class, relation)
        when 'sqlite', 'sqlite3'
          explain_sqlite(model_class, relation)
        else
          puts "Explain not supported for #{model_class.connection.adapter_name}"
        end
      rescue => e
        puts "Error getting query plan: #{e.message}"
      end
    end

    # Compare performance across different search strategies
    def self.compare_strategies(model_class, query, iterations: 100)
      return unless model_class.respond_to?(:search)
      
      puts "🔍 Comparing search strategies for #{model_class.name}"
      puts "Query: '#{query}' (#{iterations} iterations)"
      puts

      strategies = []
      
      # Strategy 1: Our search method
      strategies << ["SearchableRecords", -> { model_class.search(query).load }]
      
      # Strategy 2: Manual LIKE queries for comparison
      if model_class.searchable_fields.any?
        conditions = model_class.searchable_fields.map { |field| "#{field} LIKE ?" }
        params = model_class.searchable_fields.map { "%#{query}%" }
        strategies << ["Manual LIKE", -> { model_class.where(conditions.join(" OR "), *params).load }]
      end
      
      # Strategy 3: Using raw SQL
      table_name = model_class.table_name
      fields = model_class.searchable_fields
      if fields.any?
        raw_conditions = fields.map { |field| "#{table_name}.#{field} LIKE '%#{query}%'" }.join(" OR ")
        strategies << ["Raw SQL", -> { model_class.where(raw_conditions).load }]
      end

      Benchmark.bm(20) do |x|
        strategies.each do |name, strategy|
          x.report("#{name}:") do
            iterations.times { strategy.call }
          end
        end
      end
    end

    # Memory usage analysis
    def self.analyze_memory_usage(model_class, query, record_count: 1000)
      return unless model_class.respond_to?(:search)
      
      puts "🔍 Memory usage analysis for #{model_class.name}"
      puts "Query: '#{query}'"
      puts "Expected results: ~#{record_count} records"
      puts

      # Measure memory before
      gc_stats_before = GC.stat
      memory_before = get_memory_usage
      
      results = model_class.search(query).limit(record_count)
      loaded_results = results.load
      
      # Measure memory after
      gc_stats_after = GC.stat
      memory_after = get_memory_usage
      
      puts "Memory usage:"
      puts "  Before: #{format_bytes(memory_before)}"
      puts "  After:  #{format_bytes(memory_after)}"
      puts "  Delta:  #{format_bytes(memory_after - memory_before)}"
      puts
      puts "Garbage collection:"
      puts "  Objects allocated: #{gc_stats_after[:total_allocated_objects] - gc_stats_before[:total_allocated_objects]}"
      puts "  GC runs: #{gc_stats_after[:count] - gc_stats_before[:count]}"
      puts
      puts "Results:"
      puts "  Records loaded: #{loaded_results.size}"
      puts "  Average memory per record: #{format_bytes((memory_after - memory_before) / [loaded_results.size, 1].max)}"
    end

    private

    def self.explain_postgresql(model_class, relation)
      puts "PostgreSQL Execution Plan:"
      plan = model_class.connection.execute("EXPLAIN ANALYZE #{relation.to_sql}")
      plan.each { |row| puts "  #{row.values.first}" }
    end

    def self.explain_mysql(model_class, relation)
      puts "MySQL Execution Plan:"
      plan = model_class.connection.execute("EXPLAIN #{relation.to_sql}")
      plan.each { |row| puts "  #{row.to_a.join(' | ')}" }
    end

    def self.explain_sqlite(model_class, relation)
      puts "SQLite Query Plan:"
      plan = model_class.connection.execute("EXPLAIN QUERY PLAN #{relation.to_sql}")
      plan.each { |row| puts "  #{row.to_a.join(' | ')}" }
    end

    def self.get_memory_usage
      # Ruby memory usage in bytes
      GC.stat[:heap_allocated_pages] * GC.stat[:heap_live_slots] * 40 # approximate
    rescue
      0
    end

    def self.format_bytes(bytes)
      units = ['B', 'KB', 'MB', 'GB']
      unit_index = 0
      size = bytes.to_f

      while size >= 1024 && unit_index < units.length - 1
        size /= 1024
        unit_index += 1
      end

      "#{size.round(2)} #{units[unit_index]}"
    end
  end
end