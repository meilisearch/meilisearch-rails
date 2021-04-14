begin
  require 'will_paginate/collection'
rescue LoadError
  raise(MeiliSearch::BadConfiguration, "MeiliSearch: Please add 'will_paginate' to your Gemfile to use will_paginate pagination backend")
end

module MeiliSearch
  module Pagination
    class WillPaginate
      def self.create(results, total_hits, options = {})
        ::WillPaginate::Collection.create(options[:page].to_i, options[:per_page].to_i, total_hits) do  |pager|
          start = (options[:page].to_i * options[:per_page].to_i) - 1
          paginated_results = results[start, options[:per_page].to_i]
          pager.replace paginated_results
        end
      end
    end
  end
end
