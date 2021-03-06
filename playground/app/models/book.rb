class Book < ApplicationRecord
  include MeiliSearch

  meilisearch do
    # add_attribute :extra_attr
    searchable_attributes [:title, :author, :publisher, :description]
    attributes_for_faceting [:genre]
    ranking_rules [
      'proximity',
      'typo',
      'words',
      'attribute',
      'wordsPosition',
      'exactness',
      'desc(publication_year)',
    ]
    attributes_to_highlight ['*']
    attributes_to_crop [:description]
    crop_length 10
    synonyms man: ['life']
  end

  # def extra_attr
  #   "extra_val"
  # end
end
