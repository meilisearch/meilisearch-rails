module MeiliSearch
  module Pagination

    autoload :WillPaginate, 'meilisearch/pagination/will_paginate'
    autoload :Kaminari, 'meilisearch/pagination/kaminari'

    def self.create(results, total_hits, options = {})
      return results if MeiliSearch.configuration[:pagination_backend].nil?
      begin
        backend = MeiliSearch.configuration[:pagination_backend].to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase } # classify pagination backend name
        page = Object.const_get(:MeiliSearch).const_get(:Pagination).const_get(backend).create(results, total_hits, options)
        page
      rescue NameError
        raise(BadConfiguration, "Unknown pagination backend")
      end
    end
    
  end
end
