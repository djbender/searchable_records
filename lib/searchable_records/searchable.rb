module SearchableRecords
  module Searchable
    def searchable
      include SearchableRecords::InstanceMethods
      extend SearchableRecords::ClassMethods
    end
  end

  module ClassMethods
    def search(query)
      return none if query.blank?
      
      conditions = []
      params = {}
      
      searchable_fields.each_with_index do |column_name, index|
        param_key = "search_param_#{index}".to_sym
        conditions << "#{table_name}.#{column_name} LIKE :#{param_key}"
        params[param_key] = "%#{query}%"
      end
      
      return none if conditions.empty?
      where(conditions.join(" OR "), params)
    end

    def searchable_fields
      searchable_column_names
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
      # Skeleton for checking if instance is searchable
      true
    end

    def search_data
      # Skeleton for extracting searchable data from instance
    end
  end
end

ActiveRecord::Base.extend(SearchableRecords::Searchable)