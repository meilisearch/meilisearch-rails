require 'kaminari'
require 'support/async_helper'
require 'support/models/restaurant'

describe 'Pagination with kaminari' do
  before(:all) do
    Meilisearch::Rails.configuration[:pagination_backend] = :kaminari
    Restaurant.clear_index!

    3.times do
      Restaurant.create(
        name: Faker::Restaurant.name,
        kind: Faker::Restaurant.type,
        description: Faker::Restaurant.description
      )
    end

    AsyncHelper.await_last_task
  end

  it 'paginates' do
    first, second = Restaurant.search ''

    p1 = Restaurant.search '', page: 1, hits_per_page: 1
    expect(p1).to be_one
    expect(p1).to contain_exactly(first)

    p2 = Restaurant.search '', page: 2, hits_per_page: 1
    expect(p2).to be_one
    expect(p2).to contain_exactly(second)
  end

  it 'returns number of total results' do
    hits = Restaurant.search ''
    expect(hits.total_count).to eq(2)

    p1 = Restaurant.search '', page: 1, hits_per_page: 1
    expect(p1.total_count).to eq(2)
  end

  it 'respects both camelCase options' do
    # TODO: deprecate all camelcase attributes on v1.
    restaurants = Restaurant.search '', { page: 1, hitsPerPage: 1 }

    expect(restaurants).to be_one
    expect(restaurants.total_count).to be > 1
  end

  it 'accepts string options' do
    p1 = Restaurant.search '', page: '1', hits_per_page: '1'
    expect(p1).to be_one
    expect(p1.total_count).to eq(Restaurant.raw_search('')['hits'].count)

    p2 = Restaurant.search '', page: '2', hits_per_page: '1'
    expect(p2.size).to eq(1)
    expect(p2.total_count).to eq(Restaurant.raw_search('')['hits'].count)
  end

  it 'respects max_total_hits' do
    expect(Restaurant.search('*').count).to eq(2)
  end
end
