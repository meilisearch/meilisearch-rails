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
        semaphore.synchronize do
          @_config.merge!(active: false)

          return unless block_given?

          yield

          @_config.merge!(active: true)
        end
      end

      def activate!
        semaphore.synchronize do
          @_config.merge!(active: true)
        end
      end

      def active?
        configuration.fetch(:active, true)
      end

      def black_hole
        @black_hole ||= NullObject.instance
      end

      def semaphore
        @mutex ||= Mutex.new
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
