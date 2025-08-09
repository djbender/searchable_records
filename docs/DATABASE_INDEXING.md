# Database Indexing Guide for SearchableRecords

This guide provides detailed recommendations for optimizing database performance when using SearchableRecords.

## Overview

SearchableRecords performs substring searches using database-specific patterns:
- **Case-insensitive**: `LOWER(column) LIKE '%query%'`
- **Case-sensitive (SQLite)**: `column GLOB '*query*'`

These patterns require specialized indexing strategies for optimal performance.

## Database-Specific Recommendations

### PostgreSQL (Recommended for Production)

PostgreSQL offers the best support for substring search optimization through trigram indexes.

#### Setup Trigram Extension

```sql
-- Enable the pg_trgm extension (run as superuser)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

#### Basic Trigram Indexes

```ruby
class AddTrigramIndexesToUsers < ActiveRecord::Migration[7.0]
  def up
    # Enable extension in Rails migration
    enable_extension 'pg_trgm'
    
    # Add trigram GIN indexes for fast substring searches
    add_index :users, :name, using: :gin, opclass: :gin_trgm_ops
    add_index :users, :email, using: :gin, opclass: :gin_trgm_ops
    add_index :users, :bio, using: :gin, opclass: :gin_trgm_ops
  end

  def down
    remove_index :users, :name
    remove_index :users, :email
    remove_index :users, :bio
    disable_extension 'pg_trgm'
  end
end
```

#### Case-Insensitive Optimization

For case-insensitive searches, consider expression indexes:

```ruby
class AddCaseInsensitiveIndexes < ActiveRecord::Migration[7.0]
  def up
    # Expression indexes for case-insensitive searches
    execute <<-SQL
      CREATE INDEX CONCURRENTLY users_lower_name_trgm_idx 
      ON users USING gin (LOWER(name) gin_trgm_ops);
    SQL
    
    execute <<-SQL
      CREATE INDEX CONCURRENTLY users_lower_email_trgm_idx 
      ON users USING gin (LOWER(email) gin_trgm_ops);
    SQL
  end

  def down
    execute "DROP INDEX CONCURRENTLY IF EXISTS users_lower_name_trgm_idx;"
    execute "DROP INDEX CONCURRENTLY IF EXISTS users_lower_email_trgm_idx;"
  end
end
```

#### Performance Tuning

```sql
-- Adjust trigram similarity threshold (default 0.3)
SET pg_trgm.similarity_threshold = 0.1;

-- Check trigram similarity
SELECT similarity('SearchableRecords', 'Searchable');
```

### MySQL

MySQL full-text indexes work well for word-based searches but have limitations with short strings.

#### InnoDB Full-Text Indexes

```ruby
class AddFullTextIndexesToUsers < ActiveRecord::Migration[7.0]
  def up
    # Individual column indexes
    execute "ALTER TABLE users ADD FULLTEXT KEY ft_name (name)"
    execute "ALTER TABLE users ADD FULLTEXT KEY ft_email (email)"
    execute "ALTER TABLE users ADD FULLTEXT KEY ft_bio (bio)"
    
    # Combined index for multi-column searches (more storage efficient)
    execute "ALTER TABLE users ADD FULLTEXT KEY ft_searchable (name, email, bio)"
  end

  def down
    execute "ALTER TABLE users DROP KEY ft_name"
    execute "ALTER TABLE users DROP KEY ft_email"
    execute "ALTER TABLE users DROP KEY ft_bio"
    execute "ALTER TABLE users DROP KEY ft_searchable"
  end
end
```

#### MyISAM Full-Text (Legacy)

```ruby
# Only if using MyISAM storage engine (not recommended for new applications)
class ConvertToMyisamForFullText < ActiveRecord::Migration[7.0]
  def up
    execute "ALTER TABLE users ENGINE=MyISAM"
    execute "ALTER TABLE users ADD FULLTEXT(name, email, bio)"
  end

  def down
    execute "ALTER TABLE users DROP INDEX name"
    execute "ALTER TABLE users ENGINE=InnoDB"
  end
end
```

#### MySQL Configuration

```sql
-- Minimum word length for full-text indexing (default 4)
SET GLOBAL ft_min_word_len = 2;

-- Boolean mode search (for exact substring matching)
SELECT * FROM users WHERE MATCH(name) AGAINST('+john' IN BOOLEAN MODE);
```

### SQLite

SQLite has limited full-text search capabilities. Standard B-tree indexes provide minimal benefit for substring searches.

#### Basic B-Tree Indexes

```ruby
class AddBasicIndexesToUsers < ActiveRecord::Migration[7.0]
  def change
    # Standard indexes - limited benefit for LIKE '%query%'
    add_index :users, :name
    add_index :users, :email
    add_index :users, :bio
    
    # Composite index if searching multiple fields together frequently
    add_index :users, [:name, :email]
  end
end
```

#### FTS5 Extension (Advanced)

```ruby
class AddFts5SearchToUsers < ActiveRecord::Migration[7.0]
  def up
    # Create FTS5 virtual table
    execute <<-SQL
      CREATE VIRTUAL TABLE users_fts USING fts5(
        name,
        email, 
        bio,
        content='users',
        content_rowid='id'
      );
    SQL
    
    # Populate FTS table
    execute <<-SQL
      INSERT INTO users_fts(rowid, name, email, bio)
      SELECT id, name, email, bio FROM users;
    SQL
    
    # Triggers to keep FTS table in sync
    execute <<-SQL
      CREATE TRIGGER users_ai AFTER INSERT ON users BEGIN
        INSERT INTO users_fts(rowid, name, email, bio) 
        VALUES (new.id, new.name, new.email, new.bio);
      END;
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS users_ai"
    execute "DROP TABLE IF EXISTS users_fts"
  end
end
```

## Index Strategy by Use Case

### High-Volume Applications

For applications with millions of records and frequent searches:

```ruby
# PostgreSQL - Comprehensive trigram setup
class OptimizeForHighVolume < ActiveRecord::Migration[7.0]
  def up
    enable_extension 'pg_trgm'
    
    # Concurrent index creation to avoid downtime
    add_index :users, :name, using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently
    add_index :users, :email, using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently
    
    # Expression indexes for case-insensitive searches
    execute <<-SQL
      CREATE INDEX CONCURRENTLY users_name_lower_trgm_idx 
      ON users USING gin (LOWER(name) gin_trgm_ops);
    SQL
  end
end
```

### Scoped Field Applications

When using `searchable fields: [:specific_columns]`:

```ruby
class User < ApplicationRecord
  searchable fields: [:name, :email]  # Only search these fields
end

# Index only the searched fields
class AddScopedIndexes < ActiveRecord::Migration[7.0]
  def change
    # PostgreSQL
    add_index :users, :name, using: :gin, opclass: :gin_trgm_ops
    add_index :users, :email, using: :gin, opclass: :gin_trgm_ops
    # Don't index :bio since it's not searched
  end
end
```

### Mixed Case Sensitivity

When some models use case-sensitive search:

```ruby
class Product < ApplicationRecord
  searchable fields: [:name], case_sensitive: true
end

class User < ApplicationRecord  
  searchable fields: [:name], case_sensitive: false
end

# Different indexing strategies
class AddMixedCaseIndexes < ActiveRecord::Migration[7.0]
  def change
    # Case-sensitive model - standard trigram index
    add_index :products, :name, using: :gin, opclass: :gin_trgm_ops
    
    # Case-insensitive model - expression index on LOWER()
    execute <<-SQL
      CREATE INDEX users_name_lower_trgm_idx 
      ON users USING gin (LOWER(name) gin_trgm_ops);
    SQL
  end
end
```

## Performance Testing

### Benchmarking Queries

```ruby
# Benchmark search performance
require 'benchmark'

# Without index
Benchmark.bm do |x|
  x.report("No index:") { User.search("john").count }
end

# Add appropriate index, then test again
User.connection.add_index :users, :name, using: :gin, opclass: :gin_trgm_ops

Benchmark.bm do |x|
  x.report("With trigram:") { User.search("john").count }
end
```

### Query Plan Analysis

```ruby
# Check if indexes are being used
def analyze_search_query(query)
  sql = User.search(query).to_sql
  plan = User.connection.execute("EXPLAIN ANALYZE #{sql}")
  puts plan.to_a
end

analyze_search_query("john")
```

### Index Size Monitoring

```sql
-- PostgreSQL - Check index sizes
SELECT
  indexname,
  pg_size_pretty(pg_total_relation_size(indexname::regclass)) as size
FROM pg_indexes 
WHERE tablename = 'users';

-- MySQL - Check index cardinality
SHOW INDEX FROM users;

-- SQLite - Check index information  
.indices users
```

## Best Practices

1. **Start with PostgreSQL** for production applications requiring fast substring search
2. **Index only searched fields** to minimize storage overhead
3. **Use CONCURRENTLY** when adding indexes to large tables in production
4. **Monitor query plans** to ensure indexes are being used
5. **Consider expression indexes** for case-insensitive searches on case-sensitive databases
6. **Test with production data volumes** before deploying indexing changes
7. **Regular VACUUM/ANALYZE** (PostgreSQL) to maintain index performance
8. **Monitor index bloat** and rebuild when necessary

## Troubleshooting

### Common Issues

**Indexes not being used:**
```sql
-- Check if trigram extension is enabled
SELECT * FROM pg_extension WHERE extname = 'pg_trgm';

-- Verify index exists
\d+ users
```

**Poor performance despite indexes:**
```sql
-- Check table statistics are up to date
ANALYZE users;

-- Verify trigram threshold
SHOW pg_trgm.similarity_threshold;
```

**High storage usage:**
```sql
-- Check index sizes vs table size
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(tablename::regclass)) as table_size,
  pg_size_pretty(pg_indexes_size(tablename::regclass)) as index_size
FROM pg_tables 
WHERE tablename = 'users';
```

This comprehensive indexing strategy will significantly improve SearchableRecords performance in production environments.