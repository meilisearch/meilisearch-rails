class Song < ApplicationRecord
  include MeiliSearch::Rails
  extend Pagy::Meilisearch

  meilisearch
end
