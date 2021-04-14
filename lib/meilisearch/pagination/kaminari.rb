unless defined? Kaminari
  raise(MeiliSearch::BadConfiguration, "MeiliSearch: Please add 'kaminari' to your Gemfile to use kaminari pagination backend")
end

require "kaminari/models/array_extension"

module MeiliSearch
  module Pagination
    class Kaminari < ::Kaminari::PaginatableArray

      def initialize(array, options)
        super(array, options)
      end

      def limit(num)
        # noop
        self
      end

      def offset(num)
        # noop
        self
      end

      class << self
        def create(results, total_hits, options = {})
          offset = ((options[:page].to_i - 1) * options[:per_page].to_i)
          array = new results, :offset => offset, :limit => options[:per_page], :total_count => total_hits
          if array.empty? and !results.empty?
            # since Kaminari 0.16.0, you need to pad the results with nil values so it matches the offset param
            # otherwise you'll get an empty array: https://github.com/amatsuda/kaminari/commit/29fdcfa8865f2021f710adaedb41b7a7b081e34d
            results = ([nil] * offset) + results
            array = new results, :offset => offset, :limit => options[:per_page], :total_count => total_hits
          end
          array
        end
      end
    end
  end
end
