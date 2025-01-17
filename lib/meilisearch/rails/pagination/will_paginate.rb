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
          total_hits = 0 if Utilities.null_object?(total_hits)
          options[:page] = 1 if Utilities.null_object?(options[:page])
          options[:per_page] = 1 if Utilities.null_object?(options[:per_page])

          ::WillPaginate::Collection.create(options[:page], options[:per_page], total_hits) do |pager|
            pager.replace results
          end
        end
      end
    end
  end
end
