# SearchableRecords Performance Guide

This guide covers all performance-related features and optimizations in SearchableRecords.

## Overview

SearchableRecords is designed for high-performance substring search across multiple databases. It includes:

- **Database-specific query optimizations**
- **Built-in performance analysis tools**
- **ActiveRecord::Relation chaining and lazy evaluation**
- **Comprehensive indexing recommendations**

## Database-Specific Query Optimizations

SearchableRecords automatically detects your database adapter and uses the most efficient query patterns:

### PostgreSQL Optimizations

**Case-Insensitive Search** (default):
```sql
-- Uses native ILIKE operator for best performance
SELECT * FROM users WHERE name ILIKE '%john%' OR email ILIKE '%john%';
```

**Case-Sensitive Search**:
```sql
-- PostgreSQL LIKE is case-sensitive by default
SELECT * FROM users WHERE name LIKE '%John%' OR email LIKE '%John%';
```

**Benefits**:
- ILIKE is optimized for trigram indexes
- No function calls needed (more efficient than LOWER())
- Native PostgreSQL case handling

### MySQL Optimizations

**Case-Insensitive Search** (default):
```sql
-- Uses Unicode collation for proper case handling
SELECT * FROM users WHERE name LIKE '%john%' COLLATE utf8mb4_unicode_ci 
                        OR email LIKE '%john%' COLLATE utf8mb4_unicode_ci;
```

**Case-Sensitive Search**:
```sql
-- Uses binary collation for exact case matching
SELECT * FROM users WHERE name LIKE '%John%' COLLATE utf8mb4_bin 
                        OR email LIKE '%John%' COLLATE utf8mb4_bin;
```

**Benefits**:
- More efficient than BINARY operator
- Proper Unicode handling
- Works with MySQL full-text indexes

### SQLite Optimizations

**Case-Insensitive Search** (default):
```sql
-- SQLite LIKE is case-insensitive, but we use LOWER() for consistency
SELECT * FROM users WHERE LOWER(name) LIKE '%john%' OR LOWER(email) LIKE '%john%';
```

**Case-Sensitive Search**:
```sql
-- Uses GLOB for case-sensitive pattern matching
SELECT * FROM users WHERE name GLOB '*John*' OR email GLOB '*John*';
```

**Benefits**:
- GLOB provides exact case matching
- LOWER() ensures consistent behavior
- Optimized for SQLite's architecture

## Performance Analysis Tools

SearchableRecords includes comprehensive performance analysis tools accessible through the `SearchableRecords::Performance` module.

### Benchmarking

Compare search performance across different scenarios:

```ruby
# Basic benchmarking
SearchableRecords::Performance.benchmark_search(User, "john", iterations: 1000)

# Output:
# 🔍 Benchmarking search performance for User
# Query: 'john' (1000 iterations)
# Database: PostgreSQL
# Total records: 50000
# Searchable fields: name, email, bio
#
#                           user     system      total        real
# Search execution:     0.234000   0.012000   0.246000 (  0.267123)
# Search + count:       0.189000   0.008000   0.197000 (  0.203456)
# Search + first:       0.156000   0.006000   0.162000 (  0.178901)
# Search + limit(10):   0.145000   0.005000   0.150000 (  0.167890)
```

### Query Plan Analysis

Understand how your database executes search queries:

```ruby
SearchableRecords::Performance.explain_search(User, "john")

# Output (PostgreSQL):
# 🔍 Query Analysis for User
# Query: 'john'
# Database: PostgreSQL
# 
# Generated SQL:
# SELECT "users".* FROM "users" WHERE (users.name ILIKE '%john%' OR users.email ILIKE '%john%')
# 
# PostgreSQL Execution Plan:
#   Bitmap Heap Scan on users  (cost=12.34..567.89 rows=123 width=456)
#   Recheck Cond: ((name ~~* '%john%'::text) OR (email ~~* '%john%'::text))
#   ->  BitmapOr  (cost=12.34..12.34 rows=123 width=0)
#         ->  Bitmap Index Scan on users_name_trgm_idx  (cost=0.00..6.17 rows=62 width=0)
#               Index Cond: (name ~~* '%john%'::text)
#         ->  Bitmap Index Scan on users_email_trgm_idx  (cost=0.00..6.17 rows=61 width=0)
#               Index Cond: (email ~~* '%john%'::text)
```

### Strategy Comparison

Compare SearchableRecords against alternative approaches:

```ruby
SearchableRecords::Performance.compare_strategies(User, "john", iterations: 100)

# Output:
# 🔍 Comparing search strategies for User
# Query: 'john' (100 iterations)
# 
#                           user     system      total        real
# SearchableRecords:    0.045000   0.002000   0.047000 (  0.052123)
# Manual LIKE:          0.048000   0.002000   0.050000 (  0.055234)
# Raw SQL:              0.043000   0.002000   0.045000 (  0.049567)
```

### Memory Analysis

Understand memory usage patterns:

```ruby
SearchableRecords::Performance.analyze_memory_usage(User, "john", record_count: 1000)

# Output:
# 🔍 Memory usage analysis for User
# Query: 'john'
# Expected results: ~1000 records
# 
# Memory usage:
#   Before: 45.67 MB
#   After:  52.34 MB
#   Delta:  6.67 MB
# 
# Garbage collection:
#   Objects allocated: 12567
#   GC runs: 2
# 
# Results:
#   Records loaded: 987
#   Average memory per record: 6.76 KB
```

### Command-Line Performance Testing

Use the included command-line tool for quick performance testing:

```bash
# Create test data
bin/performance-test setup 10000

# Benchmark search performance
bin/performance-test benchmark "user" 500

# Analyze query execution
bin/performance-test explain "developer"

# Compare strategies
bin/performance-test compare "test" 100

# Analyze memory usage
bin/performance-test memory "search" 1000
```

## ActiveRecord::Relation Integration

SearchableRecords returns proper ActiveRecord::Relation objects, enabling:

### Lazy Evaluation

Queries are not executed until results are accessed:

```ruby
# No database query executed yet
relation = User.search("developer")

# Still no query - just building the relation
filtered = relation.where(active: true).order(:name)

# Query executes now when results are accessed
results = filtered.limit(10).to_a
```

### Method Chaining

Combine search with any ActiveRecord method:

```ruby
# Complex query building
User.search("ruby developer")
    .where(active: true)
    .where("created_at > ?", 1.year.ago)
    .includes(:posts)
    .order(:name)
    .limit(20)
    .offset(40)

# Aggregate functions
User.search("manager").count
User.search("senior").average(:salary)
User.search("developer").group(:department).count

# Scopes and joins
User.search("consultant")
    .joins(:company)
    .where(companies: { active: true })
    .recent
    .verified
```

### Query Optimization

SearchableRecords generates efficient SQL that works well with ActiveRecord's query optimization:

```ruby
# Single optimized query combining search with other conditions
users = User.search("developer")
            .where(active: true)
            .order(:created_at)
            .limit(10)

# Generated SQL (PostgreSQL):
# SELECT "users".* FROM "users" 
# WHERE (users.name ILIKE '%developer%' OR users.bio ILIKE '%developer%') 
#   AND "users"."active" = TRUE 
# ORDER BY "users"."created_at" 
# LIMIT 10
```

## Performance Best Practices

### 1. Use Database Indexes

Always add appropriate indexes for your searchable columns. See [DATABASE_INDEXING.md](./DATABASE_INDEXING.md) for detailed recommendations.

**PostgreSQL** (best performance):
```sql
CREATE EXTENSION pg_trgm;
CREATE INDEX CONCURRENTLY users_name_trgm_idx ON users USING gin (name gin_trgm_ops);
CREATE INDEX CONCURRENTLY users_email_trgm_idx ON users USING gin (email gin_trgm_ops);
```

**MySQL**:
```sql
ALTER TABLE users ADD FULLTEXT(name, email, bio);
```

**SQLite**:
```sql
CREATE INDEX users_name_idx ON users (name);
CREATE INDEX users_email_idx ON users (email);
```

### 2. Limit Searchable Fields

Use field scoping to search only necessary columns:

```ruby
# Instead of searching all text fields
class User < ApplicationRecord
  searchable  # Searches name, email, bio, notes, etc.
end

# Search only specific fields for better performance
class User < ApplicationRecord
  searchable fields: [:name, :email]  # Much faster
end
```

### 3. Use Appropriate Case Sensitivity

Choose the right case sensitivity setting for your use case:

```ruby
# Case-insensitive (default) - good for user-facing search
class User < ApplicationRecord
  searchable case_sensitive: false
end

# Case-sensitive - better performance, exact matching
class SystemLog < ApplicationRecord
  searchable case_sensitive: true
end
```

### 4. Chain Efficiently

Take advantage of ActiveRecord::Relation chaining:

```ruby
# Good - single query with all conditions
User.search("developer").where(active: true).limit(10)

# Avoid - multiple queries
users = User.search("developer").to_a
active_users = users.select(&:active?).first(10)
```

### 5. Use Limits for Large Result Sets

Always limit results for user-facing searches:

```ruby
# Good - prevents loading thousands of records
User.search(params[:q]).limit(50)

# Risky - might load entire table
User.search(params[:q]).to_a
```

### 6. Monitor Performance

Use the built-in performance tools to identify bottlenecks:

```ruby
# In development/staging
if Rails.env.development?
  SearchableRecords::Performance.explain_search(User, params[:query])
end

# Benchmark critical search operations
SearchableRecords::Performance.benchmark_search(User, "common query", iterations: 100)
```

## Production Deployment Considerations

### Database Configuration

**PostgreSQL**:
- Enable `pg_trgm` extension
- Adjust `pg_trgm.similarity_threshold` if needed
- Monitor index usage with `pg_stat_user_indexes`

**MySQL**:
- Set appropriate `ft_min_word_len` (default 4)
- Consider `innodb_ft_enable_stopword = OFF` for short queries
- Monitor full-text index usage

**SQLite**:
- Consider FTS5 virtual tables for large datasets
- Monitor query performance with `EXPLAIN QUERY PLAN`

### Monitoring

Monitor search performance in production:

```ruby
# Add to ApplicationController or search controller
def search
  query = params[:q]
  
  # Log search performance
  benchmark = Benchmark.measure do
    @results = User.search(query).limit(50)
  end
  
  Rails.logger.info "Search query='#{query}' time=#{benchmark.real}s results=#{@results.size}"
  
  render :search
end
```

### Caching

Consider caching for frequent searches:

```ruby
# Cache popular search results
def search
  cache_key = "search:users:#{params[:q]}:#{params[:page]}"
  
  @results = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
    User.search(params[:q])
        .includes(:avatar)
        .page(params[:page])
        .per(25)
  end
end
```

This comprehensive performance optimization makes SearchableRecords production-ready for high-traffic applications with excellent search performance across all supported databases.