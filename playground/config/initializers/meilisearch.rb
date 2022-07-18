MeiliSearch::Rails.configuration = {
    meilisearch_host: ENV.fetch('MEILISEARCH_HOST', 'http://localhost:7700'),
    meilisearch_api_key: 'masterKey',
    pagination_backend: :kaminari #:will_paginate
}
