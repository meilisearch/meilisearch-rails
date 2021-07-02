module MeiliSearch
  module Configuration
    def configuration
      @@configuration || raise(NotConfigured, "Please configure MeiliSearch. Set MeiliSearch.configuration = {meilisearch_host: 'YOUR_MEILISEARCH_HOST', meilisearch_api_key: 'YOUR_API_KEY'}")
    end

    def configuration=(configuration)
      @@configuration = configuration
    end

    def client
      ::MeiliSearch::Client.new(
        configuration[:meilisearch_host],
        configuration[:meilisearch_api_key],
        **configuration.slice(:timeout, :max_retries)
      )
    end
  end
end
