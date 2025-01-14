require 'will_paginate'
require 'support/async_helper'
require 'support/models/movie'

describe 'Pagination with will_paginate' do
  before(:all) do
    Meilisearch::Rails.configuration[:pagination_backend] = :will_paginate
    Movie.clear_index!

    6.times { Movie.create(title: Faker::Movie.title) }

    AsyncHelper.await_last_task
  end

  it 'paginates with sort' do
    unpaged_hits = Movie.search ''

    hits = Movie.search '', hits_per_page: 2
    expect(hits).to eq(unpaged_hits[0..1])

    hits = Movie.search '', hits_per_page: 2, page: 2
    expect(hits).to eq(unpaged_hits[2..3])
  end

  it 'returns paging metadata' do
    hits = Movie.search '', hits_per_page: 2
    expect(hits.per_page).to eq(2)
    expect(hits.total_pages).to eq(3)
    expect(hits.total_entries).to eq(5)
  end

  it 'accepts string options' do
    hits = Movie.search '', hits_per_page: '5'
    expect(hits.per_page).to eq(5)
    expect(hits.total_pages).to eq(1)
    expect(hits.current_page).to eq(1)

    hits = Movie.search '', hits_per_page: '5', page: '2'
    expect(hits.current_page).to eq(2)
  end

  it 'respects max_total_hits' do
    expect(Movie.search('*').count).to eq(5)
  end
end
