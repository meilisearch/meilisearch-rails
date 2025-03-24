require_relative 'multi_search/multi_search_result'
require_relative 'multi_search/federated_search_result'

module Meilisearch
  module Rails
    class << self
      def multi_search(searches)
        search_parameters = searches.map do |(index_target, options)|
          model_class = options[:scope].respond_to?(:model) ? options[:scope].model : options[:scope]
          index_target = options.delete(:index_uid) || model_class || index_target

          paginate(options) if pagination_enabled?
          normalize(options, index_target)
        end

        MultiSearchResult.new(searches, client.multi_search(queries: search_parameters))
      end

      def federated_search(queries:, federation: {})
        if federation.nil?
          Meilisearch::Rails.logger.warn(
            '[meilisearch-rails] In federated_search, `nil` is an invalid `:federation` option. To explicitly use defaults, pass `{}`.'
          )

          federation = {}
        end

        queries.map! { |item| [nil, item] } if queries.is_a?(Array)

        cleaned_queries = queries.filter_map do |(index_target, options)|
          model_class = options[:scope].respond_to?(:model) ? options[:scope].model : options[:scope]
          index_target = options.delete(:index_uid) || index_target || model_class

          strip_pagination_options(options)
          normalize(options, index_target)
        end

        raw_results = client.multi_search(queries: cleaned_queries, federation: federation)

        FederatedSearchResult.new(queries, raw_results)
      end

      private

      def normalize(options, index_target)
        index_target = index_uid_from_target(index_target)

        return nil if index_target.nil?

        options
          .except(:class_name, :scope)
          .merge!(index_uid: index_target)
      end

      def index_uid_from_target(index_target)
        case index_target
        when String, Symbol
          index_target
        when Class
          if index_target.respond_to?(:index)
            index_target.index.uid
          else
            Meilisearch::Rails.logger.warn <<~MODEL_NOT_INDEXED
              [meilisearch-rails] This class was passed to a multi/federated search but it does not have an #index: #{index_target}
              [meilisearch-rails] Are you sure it has a `meilisearch` block?
            MODEL_NOT_INDEXED

            nil
          end
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

      def strip_pagination_options(options)
        pagination_options = %w[page hitsPerPage hits_per_page limit offset].select do |key|
          options.delete(key) || options.delete(key.to_sym)
        end

        return if pagination_options.empty?

        Meilisearch::Rails.logger.warn <<~WRONG_PAGINATION
          [meilisearch-rails] Pagination options in federated search must apply to whole federation.
          [meilisearch-rails] These options have been removed: #{pagination_options.join(', ')}.
          [meilisearch-rails] Please pass them after queries, in the `federation:` option.
        WRONG_PAGINATION
      end

      def pagination_enabled?
        Meilisearch::Rails.configuration[:pagination_backend]
      end
    end
  end
end
