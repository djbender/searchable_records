# Example migration for adding SearchableRecords indexes
# Copy this file to your Rails db/migrate directory and customize for your models

class AddSearchIndexes < ActiveRecord::Migration[7.0]
  # Set to false to disable transactions (required for CONCURRENTLY in PostgreSQL)
  disable_ddl_transaction!

  def up
    case connection.adapter_name.downcase
    when 'postgresql'
      add_postgresql_indexes
    when 'mysql2', 'trilogy'
      add_mysql_indexes
    when 'sqlite3'
      add_sqlite_indexes
    else
      Rails.logger.warn "Unknown database adapter: #{connection.adapter_name}. Using basic indexes."
      add_basic_indexes
    end
  end

  def down
    case connection.adapter_name.downcase  
    when 'postgresql'
      remove_postgresql_indexes
    when 'mysql2', 'trilogy'
      remove_mysql_indexes
    when 'sqlite3'
      remove_sqlite_indexes
    else
      remove_basic_indexes
    end
  end

  private

  def add_postgresql_indexes
    # Enable trigram extension
    enable_extension 'pg_trgm'
    
    # Add trigram indexes for each searchable model/column
    # Customize this list based on your searchable models
    
    # Users model example
    add_index :users, :name, using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently
    add_index :users, :email, using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently
    add_index :users, :bio, using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently
    
    # Articles model example  
    add_index :articles, :title, using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently
    add_index :articles, :content, using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently
    
    # Case-insensitive expression indexes (optional, for better case-insensitive performance)
    execute <<-SQL
      CREATE INDEX CONCURRENTLY users_name_lower_trgm_idx 
      ON users USING gin (LOWER(name) gin_trgm_ops);
    SQL
    
    execute <<-SQL  
      CREATE INDEX CONCURRENTLY articles_title_lower_trgm_idx
      ON articles USING gin (LOWER(title) gin_trgm_ops);
    SQL
  end

  def remove_postgresql_indexes
    remove_index :users, :name
    remove_index :users, :email  
    remove_index :users, :bio
    remove_index :articles, :title
    remove_index :articles, :content
    
    execute "DROP INDEX CONCURRENTLY IF EXISTS users_name_lower_trgm_idx"
    execute "DROP INDEX CONCURRENTLY IF EXISTS articles_title_lower_trgm_idx"
    
    disable_extension 'pg_trgm'
  end

  def add_mysql_indexes
    # Full-text indexes for MySQL
    
    # Users model
    execute "ALTER TABLE users ADD FULLTEXT KEY ft_name (name)"
    execute "ALTER TABLE users ADD FULLTEXT KEY ft_email (email)"  
    execute "ALTER TABLE users ADD FULLTEXT KEY ft_bio (bio)"
    
    # Articles model
    execute "ALTER TABLE articles ADD FULLTEXT KEY ft_title (title)"
    execute "ALTER TABLE articles ADD FULLTEXT KEY ft_content (content)"
    
    # Combined indexes (more storage efficient for multi-column searches)
    execute "ALTER TABLE users ADD FULLTEXT KEY ft_users_searchable (name, email, bio)"
    execute "ALTER TABLE articles ADD FULLTEXT KEY ft_articles_searchable (title, content)"
  end

  def remove_mysql_indexes  
    execute "ALTER TABLE users DROP KEY ft_name"
    execute "ALTER TABLE users DROP KEY ft_email"
    execute "ALTER TABLE users DROP KEY ft_bio" 
    execute "ALTER TABLE users DROP KEY ft_users_searchable"
    
    execute "ALTER TABLE articles DROP KEY ft_title"
    execute "ALTER TABLE articles DROP KEY ft_content"
    execute "ALTER TABLE articles DROP KEY ft_articles_searchable"
  end

  def add_sqlite_indexes
    # Basic B-tree indexes for SQLite (limited substring search benefit)
    
    # Users model
    add_index :users, :name
    add_index :users, :email
    add_index :users, :bio
    
    # Articles model  
    add_index :articles, :title
    add_index :articles, :content
  end

  def remove_sqlite_indexes
    remove_index :users, :name
    remove_index :users, :email
    remove_index :users, :bio
    remove_index :articles, :title  
    remove_index :articles, :content
  end

  def add_basic_indexes
    # Fallback for unknown database adapters
    add_index :users, :name
    add_index :users, :email
    add_index :users, :bio
    add_index :articles, :title
    add_index :articles, :content
  end

  def remove_basic_indexes
    remove_index :users, :name
    remove_index :users, :email  
    remove_index :users, :bio
    remove_index :articles, :title
    remove_index :articles, :content
  end
end

# Usage Instructions:
#
# 1. Copy this file to db/migrate/YYYYMMDDHHMMSS_add_search_indexes.rb
# 2. Customize the model and column names for your application
# 3. Run: rails db:migrate
#
# For production deployments:
# - PostgreSQL: Uses CONCURRENTLY to avoid table locks
# - MySQL: Consider running during maintenance windows for large tables  
# - SQLite: Safe to run anytime (limited indexing anyway)
#
# Performance Testing:
# - Before: Rails.logger.debug User.search("test").explain
# - After:  Rails.logger.debug User.search("test").explain
# - Compare query plans to verify index usage