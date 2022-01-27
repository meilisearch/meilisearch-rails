module MeiliSearch
  module Rails
    module Pagination
      autoload :WillPaginate, 'meilisearch/rails/pagination/will_paginate'
      autoload :Kaminari, 'meilisearch/rails/pagination/kaminari'

      def self.create(results, total_hits, options = {})
        return results if MeiliSearch::Rails.configuration[:pagination_backend].nil?

        begin
          backend = MeiliSearch::Rails.configuration[:pagination_backend].to_s.classify

          ::MeiliSearch::Rails::Pagination.const_get(backend).create(results, total_hits, options)
        rescue NameError
          raise(BadConfiguration, 'Unknown pagination backend')
        end
      end
    end
  end
end
