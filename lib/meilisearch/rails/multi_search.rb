require_relative 'multi_search/result'

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

        MultiSearchResult.new(searches, raw_results)
      end
    end
  end
end
