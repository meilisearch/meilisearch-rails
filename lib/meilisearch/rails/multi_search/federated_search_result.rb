require 'active_support/core_ext/module/delegation'

module Meilisearch
  module Rails
    class FederatedSearchResult
      attr_reader :metadata, :hits

      def initialize(searches, raw_results)
        hits = raw_results.delete('hits')
        @hits = load_hits(hits, searches.to_a)
        @metadata = raw_results
      end

      include Enumerable

      delegate :each, :to_a, :to_ary, :empty?, :[], :first, :last, to: :@hits

      private

      def load_hits(hits, searches)
        hits_by_pos = hits.group_by { |hit| hit['_federation']['queriesPosition'] }

        keys_and_records_by_pos = hits_by_pos.to_h do |pos, group_hits|
          search_target, search_opts = searches[pos]

          klass = if search_opts[:class_name]
                    search_opts[:class_name].constantize
                  elsif search_target.instance_of?(Class)
                    search_target
                  end

          if klass.present?
            [pos, load_results(klass, group_hits)]
          else
            [pos, [nil, group_hits]]
          end
        end

        hits.filter_map do |hit|
          hit_cond_key, recs_by_id = keys_and_records_by_pos[hit['_federation']['queriesPosition']]

          if hit_cond_key.present?
            record = recs_by_id[hit[hit_cond_key.to_s].to_s]
            record&.formatted = hit['_formatted']
            record
          else
            hit
          end
        end
      end

      def load_results(klass, hits)
        pk_method = klass.ms_primary_key_method
        pk_method = pk_method.in if Utilities.mongo_model?(klass)

        condition_key = pk_is_virtual?(klass, pk_method) ? klass.primary_key : pk_method

        hits_by_id = hits.index_by { |hit| hit[condition_key.to_s] }

        records = klass.where(condition_key => hits_by_id.keys)

        results_by_id = records.index_by do |record|
          record.send(condition_key).to_s
        end

        [condition_key, results_by_id]
      end

      def pk_is_virtual?(model_class, pk_method)
        model_class.columns
                   .map(&(Utilities.sequel_model?(model_class) ? :to_s : :name))
                   .exclude?(pk_method.to_s)
      end
    end
  end
end
