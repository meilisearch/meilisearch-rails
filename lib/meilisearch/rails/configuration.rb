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

      def deactivate!
        if block_given?
          @_config.merge!(active: false)

          yield

          @_config.merge!(active: true)
        else
          @_config.merge!(active: false)
        end
      end

      def activate!
        @_config.merge!(active: true)
      end

      def active?
        configuration.fetch(:active, true)
      end

      def black_hole
        @black_hole ||= NullObject.instance
      end

      def client
        return black_hole unless active?

        ::MeiliSearch::Client.new(
          configuration[:meilisearch_host] || 'http://localhost:7700',
          configuration[:meilisearch_api_key],
          configuration.slice(:timeout, :max_retries)
                       .merge(client_agents: MeiliSearch::Rails.qualified_version)
        )
      end
    end
  end
end
