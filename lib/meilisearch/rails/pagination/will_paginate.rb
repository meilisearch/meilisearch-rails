begin
  require 'will_paginate/collection'
rescue LoadError
  raise(MeiliSearch::BadConfiguration,
        "MeiliSearch: Please add 'will_paginate' to your Gemfile to use will_paginate pagination backend")
end

module MeiliSearch
  module Rails
    module Pagination
      class WillPaginate
        def self.create(results, total_hits, options = {})
          ::WillPaginate::Collection.create(options[:page], options[:per_page], total_hits) do |pager|
            start = (options[:page] - 1) * options[:per_page]
            paginated_results = results[start, options[:per_page]]
            pager.replace paginated_results
          end
        end
      end
    end
  end
end
