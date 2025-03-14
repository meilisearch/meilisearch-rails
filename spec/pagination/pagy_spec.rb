require 'support/models/movie'

describe 'Pagination with pagy' do
  it 'has meaningful error when pagy is set as the pagination_backend' do
    Movie.create(title: 'Harry Potter').index!(true)

    logger = double

    allow(logger).to receive(:warn)
    allow(Meilisearch::Rails).to receive(:logger).and_return(logger)

    Meilisearch::Rails.configuration[:pagination_backend] = :pagy

    Movie.search('')

    expect(logger).to have_received(:warn)
      .with('[meilisearch-rails] Remove `pagination_backend: :pagy` from your initializer, `pagy` it is not required for `pagy`')
  end
end
