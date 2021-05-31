module MeiliSearch
  module Configuration
    def configuration
      @@configuration || raise(NotConfigured, "Please configure MeiliSearch. Set MeiliSearch.configuration = {meilisearch_host: 'YOUR_meilisearch_host', meilisearch_api_key: 'YOUR_API_KEY'}")
    end

    def configuration=(configuration)
      @@configuration = configuration
    end

    def client
      ::MeiliSearch::Client.new(@@configuration[:meilisearch_host], @@configuration[:meilisearch_api_key])
    end
  end
end
