class Book < ApplicationRecord
    include MeiliSearch

    meilisearch do
        # add_attribute :extra_attr
        searchableAttributes ['title', 'author', 'publisher', 'description']
        attributesForFaceting ['genre']
        rankingRules [
            "proximity",
            "typo",
            "words",
            "attribute",
            "wordsPosition",
            "exactness",
            "desc(publication_year)"
        ]
        attributesToHighlight ['*']
        attributesToCrop ['description']
        cropLength 10
        synonyms man: ['life']
    end

    # def extra_attr
    #     "extra_val"
    # end
end
