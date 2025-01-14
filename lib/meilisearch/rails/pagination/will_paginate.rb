begin
  require 'will_paginate/collection'
rescue LoadError
  raise(Meilisearch::BadConfiguration,
        "Meilisearch: Please add 'will_paginate' to your Gemfile to use will_paginate pagination backend")
end

module Meilisearch
  module Rails
    module Pagination
      class WillPaginate
        def self.create(results, total_hits, options = {})
          ::WillPaginate::Collection.create(options[:page], options[:per_page], total_hits) do |pager|
            pager.replace results
          end
        end
      end
    end
  end
end
