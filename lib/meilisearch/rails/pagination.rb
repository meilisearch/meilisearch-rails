module Meilisearch
  module Rails
    module Pagination
      autoload :WillPaginate, 'meilisearch/rails/pagination/will_paginate'
      autoload :Kaminari, 'meilisearch/rails/pagination/kaminari'

      def self.create(results, total_hits, options = {})
        pagination_backend = Meilisearch::Rails.configuration[:pagination_backend]

        if pagination_backend.nil? || (is_pagy = pagination_backend.to_s == 'pagy')
          log_pagy_error if is_pagy

          return results
        end

        load_pagination!(pagination_backend, results, total_hits, options)
      end

      def self.log_pagy_error
        Meilisearch::Rails.logger
          .warn('[meilisearch-rails] Remove `pagination_backend: :pagy` from your initializer, `pagy` it is not required for `pagy`')
      end

      def self.load_pagination!(pagination_backend, results, total_hits, options)
        ::Meilisearch::Rails::Pagination
          .const_get(pagination_backend.to_s.classify)
          .create(results, total_hits, options)
      rescue NameError
        raise(BadConfiguration, 'Invalid `pagination_backend:` configuration, check your initializer.')
      end
    end
  end
end
