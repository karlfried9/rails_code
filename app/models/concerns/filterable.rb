module Filterable
  extend ActiveSupport::Concern

  module ClassMethods
    def filter(filtering_params, search_query, page, limit)
      results = search_query.blank? ?
                self.where(nil) :
                search(search_query).where(nil)

      filtering_params.each do |key, value|
        results = results.public_send(key, value) if value.present?
      end
      results.paginate(page, limit)
    end

    def search(query)
      if query.blank?
        self.all
      else
        table_name = self.to_s.pluralize.underscore
        query_string = ''

        like_string = 'LIKE'

        like_string = 'ILIKE' if database_type_is? :postgresql

        self.search_columns.each_with_index do |column, index|
          query_string << ' OR ' unless index == 0

          if self.columns_hash[column].type.eql?(:integer)
            query_string << "#{table_name}.#{column} = #{query}"
          else
            query_string << "#{table_name}.#{column} #{like_string} '%#{query}%'"
          end
        end

        where(query_string)
      end

    end

    def paginate(page, limit)
      limit = limit.blank? ? 10 : limit.to_i
      page = page.blank? ? 1 : page.to_i

      offset(limit * (page - 1)).limit(limit)
    end

    private

    def database_type_is?(type)
      ActiveRecord::Base.connection.adapter_name.downcase.to_sym == type
    end
  end
end
