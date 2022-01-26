module MeiliSearch
  module Rails
    module Configuration
      def configuration
        raise NotConfigured if @_config.blank?

        @_config
      end

      def configuration=(configuration)
        @_config = configuration
      end

      def client
        ::MeiliSearch::Client.new(
          configuration[:meilisearch_host] || 'http://localhost:7700',
          configuration[:meilisearch_api_key],
          configuration.slice(:timeout, :max_retries)
        )
      end
    end
  end
end
