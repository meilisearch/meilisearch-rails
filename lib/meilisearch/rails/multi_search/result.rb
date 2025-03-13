module Meilisearch
  module Rails
    class MultiSearchResult
      attr_reader :metadata

      def initialize(searches, raw_results)
        @results = {}
        @metadata = {}

        searches.zip(raw_results['results']).each do |(target, search_options), result|
          results_class = if search_options[:class_name]
                            Meilisearch::Rails.logger.warn(
                              '[meilisearch-rails] The :class_name option in multi search is deprecated, please use :collection instead.'
                            )

                            search_options[:class_name].constantize
                          elsif target.instance_of?(Class)
                            target
                          elsif search_options[:collection]
                            search_options[:collection]
                          end

          @results[target] = results_class ? load_results(results_class, result, collection: search_options[:collection]) : result['hits']

          @metadata[target] = result.except('hits')
        end
      end

      include Enumerable

      def each_hit(&block)
        Meilisearch::Rails.logger.warn(
          <<~DEPRECATION
            [meilisearch-rails] Flattening multi search results is deprecated.
            If you do not want the results to be grouped, please use federated search instead.
          DEPRECATION
        )

        @results.each_value do |results|
          results.each(&block)
        end
      end

      def each(&block)
        Meilisearch::Rails.logger.info(
          <<~INFO
            [meilisearch-rails] #each on a multi search now iterates through grouped results.
            If you do not want the results to be grouped, please use federated search instead.
            To quickly go back to the old deprecated behavior, use `#each_hit`.
          INFO
        )

        @results.each(&block)
      end

      def each_result(&block)
        @results.each(&block)
      end

      def to_a
        Meilisearch::Rails.logger.warn(
          <<~DEPRECATION
            [meilisearch-rails] Flattening multi search results is deprecated.
            If you do not want the results to be grouped, please use federated search instead.
          DEPRECATION
        )
        @results.values.flatten(1)
      end
      alias to_ary to_a

      def to_h
        @results
      end
      alias to_hash to_h

      private

      def load_results(klass, result, collection:)
        collection ||= klass

        pk_method = klass.ms_primary_key_method
        pk_method = pk_method.in if Utilities.mongo_model?(klass)

        condition_key = pk_is_virtual?(klass, pk_method) ? klass.primary_key : pk_method

        hits_by_id =
          result['hits'].index_by { |hit| hit[condition_key.to_s] }

        records = collection.where(condition_key => hits_by_id.keys)

        if records.respond_to? :in_order_of
          records.in_order_of(condition_key, hits_by_id.keys).each do |record|
            record.formatted = hits_by_id[record.send(condition_key).to_s]['_formatted']
          end
        else
          results_by_id = records.index_by do |hit|
            hit.send(condition_key).to_s
          end

          result['hits'].filter_map do |hit|
            record = results_by_id[hit[condition_key.to_s].to_s]
            record&.formatted = hit['_formatted']
            record
          end
        end
      end

      def pk_is_virtual?(model_class, pk_method)
        model_class.columns
                   .map(&(Utilities.sequel_model?(model_class) ? :to_s : :name))
                   .exclude?(pk_method.to_s)
      end
    end
  end
end
