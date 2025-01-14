class Book < ApplicationRecord
  include Meilisearch::Rails

  meilisearch do
    # add_attribute :extra_attr
    searchable_attributes [:title, :author, :publisher, :description]
    filterable_attributes [:genre]
    ranking_rules [
      'proximity',
      'typo',
      'words',
      'attribute',
      'sort',
      'exactness',
      'publication_year:desc',
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
