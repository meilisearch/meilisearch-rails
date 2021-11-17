module MeiliSearch
  module Pagination
    autoload :WillPaginate, 'meilisearch/pagination/will_paginate'
    autoload :Kaminari, 'meilisearch/pagination/kaminari'

    def self.create(results, total_hits, options = {})
      return results if MeiliSearch.configuration[:pagination_backend].nil?

      begin
        backend = MeiliSearch.configuration[:pagination_backend].to_s.classify

        ::MeiliSearch::Pagination.const_get(backend).create(results, total_hits, options)
      rescue NameError
        raise(BadConfiguration, 'Unknown pagination backend')
      end
    end
  end
end
