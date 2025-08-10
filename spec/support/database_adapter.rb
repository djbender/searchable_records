# Database adapter support for multi-database testing

module DatabaseAdapter
  def self.current_adapter
    ENV['DATABASE_ADAPTER'] || 'sqlite3'
  end
  
  def self.postgresql?
    current_adapter == 'postgresql'
  end
  
  def self.sqlite?
    current_adapter == 'sqlite3'
  end
  
  def self.mysql?
    current_adapter == 'mysql2'
  end
  
  def self.configure_activerecord
    database_config = load_database_config
    ActiveRecord::Base.establish_connection(database_config)
  end
  
  def self.load_database_config
    config_file = File.join(File.dirname(__FILE__), '..', 'database.yml')
    configs = YAML.load_file(config_file, aliases: true)
    config = configs[current_adapter]
    
    raise "Database configuration not found for adapter: #{current_adapter}" unless config
    
    # ERB processing for environment variables
    config.each do |key, value|
      if value.is_a?(String) && value.include?('<%=')
        config[key] = ERB.new(value).result
      end
    end
    
    config.symbolize_keys
  end
  
  def self.create_database_if_needed
    config = load_database_config
    
    if postgresql?
      admin_config = config.dup
      admin_config[:database] = 'postgres'
      
      begin
        ActiveRecord::Base.establish_connection(admin_config)
        ActiveRecord::Base.connection.execute("CREATE DATABASE #{config[:database]}")
        puts "Created PostgreSQL database: #{config[:database]}"
      rescue ActiveRecord::StatementInvalid => e
        # Database already exists, ignore
        puts "PostgreSQL database already exists: #{config[:database]}" if e.message.include?("already exists")
      ensure
        ActiveRecord::Base.establish_connection(config)
      end
    elsif mysql?
      admin_config = config.dup
      admin_config[:database] = 'mysql'
      
      begin
        ActiveRecord::Base.establish_connection(admin_config)
        ActiveRecord::Base.connection.execute("CREATE DATABASE IF NOT EXISTS #{config[:database]}")
        puts "Created MySQL database: #{config[:database]}"
      rescue ActiveRecord::StatementInvalid => e
        puts "MySQL database already exists: #{config[:database]}" if e.message.include?("exists")
      ensure
        ActiveRecord::Base.establish_connection(config)
      end
    end
  end
  
  def self.drop_database_if_needed
    config = load_database_config
    
    if postgresql?
      admin_config = config.dup
      admin_config[:database] = 'postgres'
      
      begin
        ActiveRecord::Base.establish_connection(admin_config)
        ActiveRecord::Base.connection.execute("DROP DATABASE IF EXISTS #{config[:database]}")
        puts "Dropped PostgreSQL database: #{config[:database]}"
      rescue ActiveRecord::StatementInvalid => e
        puts "Error dropping PostgreSQL database: #{e.message}"
      end
    elsif mysql?
      admin_config = config.dup
      admin_config[:database] = 'mysql'
      
      begin
        ActiveRecord::Base.establish_connection(admin_config)
        ActiveRecord::Base.connection.execute("DROP DATABASE IF EXISTS #{config[:database]}")
        puts "Dropped MySQL database: #{config[:database]}"
      rescue ActiveRecord::StatementInvalid => e
        puts "Error dropping MySQL database: #{e.message}"
      end
    end
  end
end