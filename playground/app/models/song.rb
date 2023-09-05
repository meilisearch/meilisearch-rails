class Song < ApplicationRecord
  include MeiliSearch::Rails
  extend Pagy::Meilisearch
  ActiveRecord_Relation.include Pagy::Meilisearch

  belongs_to :author

  meilisearch
end
