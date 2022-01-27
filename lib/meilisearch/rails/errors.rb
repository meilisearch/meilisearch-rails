module MeiliSearch
  module Rails
    class NoBlockGiven < StandardError; end

    class BadConfiguration < StandardError; end

    class NotConfigured < StandardError
      def message
        'Please configure Meilisearch. Set MeiliSearch::Rails.configuration = ' \
          "{meilisearch_host: 'YOUR_MEILISEARCH_HOST', meilisearch_api_key: 'YOUR_API_KEY'}"
      end
    end
  end
end
