class Song < ApplicationRecord
  include Meilisearch::Rails
  extend Pagy::Meilisearch
  ActiveRecord_Relation.include Pagy::Meilisearch

  belongs_to :author

  meilisearch
end
