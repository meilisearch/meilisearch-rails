unless defined? Kaminari
  raise(MeiliSearch::BadConfiguration,
        "Meilisearch: Please add 'kaminari' to your Gemfile to use kaminari pagination backend")
end

require 'kaminari/models/array_extension'

module MeiliSearch
  module Rails
    module Pagination
      class Kaminari < ::Kaminari::PaginatableArray
        def initialize(array, options)
          if RUBY_VERSION >= '3'
            super(array, **options)
          else
            super(array, options)
          end
        end

        def self.create(results, total_hits, options = {})
          offset = ((options[:page] - 1) * options[:per_page])
          total_hits = 0 if total_hits.nil?
          offset = 0 if offset.nil?
          limit = 0 if options[:per_page].nil?
          array = new results, limit: limit, offset: offset, total_count: total_hits

          if array.empty? && !results.empty?
            # since Kaminari 0.16.0, you need to pad the results with nil values so it matches the offset param
            # otherwise you'll get an empty array: https://github.com/amatsuda/kaminari/commit/29fdcfa8865f2021f710adaedb41b7a7b081e34d
            results = Array.new(offset) + results
            array = new results, offset: offset, limit: limit, total_count: total_hits
          end

          array
        end
      end
    end
  end
end
