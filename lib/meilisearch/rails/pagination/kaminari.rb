unless defined? Kaminari
  raise(Meilisearch::BadConfiguration,
        "Meilisearch: Please add 'kaminari' to your Gemfile to use kaminari pagination backend")
end

require 'kaminari/models/array_extension'

module Meilisearch
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
          array = new results, limit: options[:per_page], offset: offset, total_count: total_hits

          if array.empty? && !results.empty?
            # since Kaminari 0.16.0, you need to pad the results with nil values so it matches the offset param
            # otherwise you'll get an empty array: https://github.com/amatsuda/kaminari/commit/29fdcfa8865f2021f710adaedb41b7a7b081e34d
            results = Array.new(offset) + results
            array = new results, offset: offset, limit: options[:per_page], total_count: total_hits
          end

          array
        end
      end
    end
  end
end
