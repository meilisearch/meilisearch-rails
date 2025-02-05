require_relative 'multi_search/result'

module Meilisearch
  module Rails
    class << self
      def multi_search(searches)
        search_parameters = searches.map do |(index_target, options)|
          paginate(options) if pagination_enabled?
          normalize(options, index_target)
        end

        MultiSearchResult.new(searches, client.multi_search(search_parameters))
      end

      private

      def normalize(options, index_target)
        options
          .except(:class_name)
          .merge!(index_uid: index_uid_from_target(index_target))
      end

      def index_uid_from_target(index_target)
        case index_target
        when String, Symbol
          index_target
        else
          index_target.index.uid
        end
      end

      def paginate(options)
        %w[page hitsPerPage hits_per_page].each do |key|
          # Deletes hitsPerPage to avoid passing along a meilisearch-ruby warning/exception
          value = options.delete(key) || options.delete(key.to_sym)
          options[key.underscore.to_sym] = value.to_i if value
        end

        # It is required to activate the finite pagination in Meilisearch v0.30 (or newer),
        # to have at least `hits_per_page` defined or `page` in the search request.
        options[:page] ||= 1
      end

      def pagination_enabled?
        Meilisearch::Rails.configuration[:pagination_backend]
      end
    end
  end
end
