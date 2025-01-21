require 'support/models/color'
require 'support/models/book'

describe 'When primary key is integer' do
  it 'stays as integer in index' do
    MeiliSearch::Rails.configuration[:stringify_primary_keys] = false

    TestUtil.reset_colors!
    Color.create!(id: 1, name: 'purple', short_name: 'p')
    Color.create!(id: 2, name: 'blue', short_name: 'b')
    Color.create!(id: 10, name: 'yellow', short_name: 'l')
    raw_search_results = Color.raw_search('*', sort: ['id:asc'])['hits']
    raw_search_result_ids = raw_search_results.map { |h| h['id'].to_i }

    expect(raw_search_result_ids).to eq [1, 2, 10]

    MeiliSearch::Rails.configuration[:stringify_primary_keys] = true
  end
end
