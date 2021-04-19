class Book < ApplicationRecord
    include MeiliSearch

    meilisearch do
    end
end
