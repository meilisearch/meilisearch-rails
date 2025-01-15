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
          unless MeiliSearch::Rails.active?
            total_hits = 0
            options[:page] = 1
            options[:per_page] = 1
          end

          ::WillPaginate::Collection.create(options[:page], options[:per_page], total_hits) do |pager|
            pager.replace results
          end
        end
      end
    end
  end
end
