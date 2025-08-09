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
          # For case-sensitive search, we need to ensure exact case matching
          # SQLite LIKE is case-insensitive by default, so we use GLOB for case-sensitive
          conditions << "#{table_name}.#{column_name} GLOB :#{param_key}"
          params[param_key] = "*#{query}*"
        else
          # For case-insensitive search, use LOWER() on both sides
          conditions << "LOWER(#{table_name}.#{column_name}) LIKE :#{param_key}"
          params[param_key] = "%#{query.downcase}%"
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
