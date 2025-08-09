module SearchableRecords
  module Searchable
    def searchable(options = {})
      include SearchableRecords::InstanceMethods
      extend SearchableRecords::ClassMethods

      # Store searchable configuration as class variable
      class_variable_set(:@@searchable_config, {
        fields: options[:fields],
        case_sensitive: options.fetch(:case_sensitive, false)
      })
    end
  end

  module ClassMethods
    def search(query)
      return none if query.blank?

      conditions = []
      params = {}
      config = searchable_config

      searchable_fields.each_with_index do |column_name, index|
        param_key = "search_param_#{index}".to_sym

        if config[:case_sensitive]
          # Database-specific case-sensitive search
          case connection.adapter_name.downcase
          when 'sqlite', 'sqlite3'
            # SQLite: Use GLOB for case-sensitive pattern matching
            conditions << "#{table_name}.#{column_name} GLOB :#{param_key}"
            params[param_key] = "*#{query}*"
          when 'postgresql'
            # PostgreSQL: Use regular LIKE (PostgreSQL LIKE is case-sensitive by default)
            conditions << "#{table_name}.#{column_name} LIKE :#{param_key}"
            params[param_key] = "%#{query}%"
          when 'mysql2', 'trilogy'
            # MySQL: Use COLLATE for case-sensitive comparison (more efficient than BINARY)
            conditions << "#{table_name}.#{column_name} LIKE :#{param_key} COLLATE utf8mb4_bin"
            params[param_key] = "%#{query}%"
          else
            # Fallback: Use standard LIKE
            conditions << "#{table_name}.#{column_name} LIKE :#{param_key}"
            params[param_key] = "%#{query}%"
          end
        else
          # Database-specific case-insensitive search optimizations
          case connection.adapter_name.downcase
          when 'postgresql'
            # PostgreSQL: Use ILIKE for optimal case-insensitive performance
            conditions << "#{table_name}.#{column_name} ILIKE :#{param_key}"
            params[param_key] = "%#{query}%"
          when 'mysql2', 'trilogy'
            # MySQL: Use COLLATE for case-insensitive search
            conditions << "#{table_name}.#{column_name} LIKE :#{param_key} COLLATE utf8mb4_unicode_ci"
            params[param_key] = "%#{query}%"
          else
            # SQLite and other databases: Use LOWER() for case-insensitive search
            conditions << "LOWER(#{table_name}.#{column_name}) LIKE :#{param_key}"
            params[param_key] = "%#{query.to_s.downcase}%"
          end
        end
      end

      return none if conditions.empty?
      where(conditions.join(" OR "), params)
    end

    def searchable_fields
      config = searchable_config

      if config[:fields]
        # Filter to only include specified fields that are also searchable column types
        specified_fields = config[:fields].map(&:to_s)
        searchable_column_names.select { |name| specified_fields.include?(name) }
      else
        searchable_column_names
      end
    end

    def searchable_config
      class_variable_defined?(:@@searchable_config) ?
        class_variable_get(:@@searchable_config) :
        { fields: nil, case_sensitive: false }
    end

    private

    def searchable_column_names
      searchable_types = [:string, :text]

      columns.select do |column|
        searchable_types.include?(column.type)
      end.map(&:name)
    end
  end

  module InstanceMethods
    def searchable?
      # Check if this instance has any non-blank searchable content
      self.class.searchable_fields.any? do |field|
        value = send(field)
        value.present? && value.to_s.strip.present?
      end
    end

    def search_data
      # Return hash of searchable fields and their values
      self.class.searchable_fields.each_with_object({}) do |field, data|
        data[field] = send(field)
      end
    end
  end
end

ActiveRecord::Base.extend(SearchableRecords::Searchable)
