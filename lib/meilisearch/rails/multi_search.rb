module MeiliSearch
  module Rails
    class << self
      def multi_search(searches)
        search_parameters = searches.map do |(index_target, options)|
          index_uid = case index_target
                      when String, Symbol
                        index_target
                      else
                        index_target.index.uid
                      end

          options.except(:class_name).merge(index_uid: index_uid)
        end

        raw_results = client.multi_search(search_parameters)['results']

        searches.zip(raw_results).flat_map do |(index_target, search_options), result|
          if search_options[:class_name]
            index_target = search_options[:class_name].constantize
          end

          case index_target
          when String, Symbol
            result['hits']
          else
            load_results(index_target, result)
          end
        end
      end

      private

      def load_results(klass, result)
        pk_method = if defined?(::Mongoid::Document) && klass.include?(::Mongoid::Document)
                      klass.ms_primary_key_method.in
                    else
                      klass.ms_primary_key_method
                    end

        ms_pk = klass.meilisearch_options[:primary_key] || IndexSettings::DEFAULT_PRIMARY_KEY

        db_is_sequel = defined?(::Sequel::Model) && klass < Sequel::Model
        pk_is_virtual = klass.columns.map(&(db_is_sequel ? :to_s : :name)).exclude?(pk_method.to_s)

        condition_key = pk_is_virtual ? klass.primary_key : pk_method

        hits_by_id =
          result['hits'].index_by { |hit| hit[pk_is_virtual ? condition_key : ms_pk.to_s] }

        records = klass.where(condition_key => hits_by_id.keys)

        if records.respond_to? :in_order_of
          records.in_order_of(pk_method, hits_by_id.keys).each do |record|
            record.formatted = hits_by_id[record.send(pk_method).to_s]['_formatted']
          end
        else
          results_by_id = records.index_by do |hit|
            hit.send(pk_method).to_s
          end

          result['hits'].filter_map do |hit|
            record = results_by_id[hit[ms_pk.to_s].to_s]
            if record
              record.formatted = hit['_formatted']
              record
            end
          end
        end
      end
    end
  end
end
