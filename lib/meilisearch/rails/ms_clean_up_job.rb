module MeiliSearch
  module Rails
    class MSCleanUpJob < ::ActiveJob::Base
      queue_as :meilisearch

      def perform(documents)
        documents.each do |document|
          index = MeiliSearch::Rails.client.index(document[:index_uid])

          if document[:synchronous]
            index.delete_document!(document[:primary_key])
          else
            index.delete_document(document[:primary_key])
          end
        end
      end
    end
  end
end
