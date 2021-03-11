module MeiliSearch
  module Configuration
    def configuration
      @@configuration || raise(NotConfigured, "Please configure MeiliSearch. Set MeiliSearch.configuration = {application_id: 'YOUR_APPLICATION_ID', api_key: 'YOUR_API_KEY'}")
    end

    def configuration=(configuration)
      @@configuration = configuration
    end

    def client
      ::MeiliSearch::Client.new(@@configuration[:application_id], @@configuration[:api_key])
    end
  end
end
