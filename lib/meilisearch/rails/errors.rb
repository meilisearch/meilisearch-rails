module Meilisearch
  module Rails
    class NoBlockGiven < StandardError; end

    class BadConfiguration < StandardError; end

    class NotConfigured < StandardError
      def message
        'Please configure Meilisearch. Set Meilisearch::Rails.configuration = ' \
          "{meilisearch_url: 'YOUR_MEILISEARCH_URL', meilisearch_api_key: 'YOUR_API_KEY'}"
      end
    end
  end
end
