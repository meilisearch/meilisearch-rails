require 'spec_helper'

describe Meilisearch::Rails::FederatedSearchResult do # rubocop:todo RSpec/FilePath
  subject(:result) { described_class.new(searches, raw_results) }

  let(:raw_results) do
    {
      'hits' => [
        { 'name' => 'Steve Jobs', 'id' => '3', 'author' => 'Walter Isaacson', 'premium' => nil, 'released' => nil, 'genre' => nil,
          '_federation' => { 'queriesPosition' => 0 } },
        { 'id' => '4', 'href' => 'ebay', 'name' => 'palm pixi plus', '_federation' => { 'queriesPosition' => 1 } },
        { 'name' => 'black', 'id' => '5', 'short_name' => 'bla', 'hex' => 0, '_federation' => { 'queriesPosition' => 2 } },
        { 'name' => 'blue', 'id' => '4', 'short_name' => 'blu', 'hex' => 255, '_federation' => { 'queriesPosition' => 2 } }
      ],
      'offset' => 10,
      'limit' => 5
    }
  end

  let(:searches) do
    {
      'books_index' => { q: 'Steve' },
      'products_index' => { q: 'palm' },
      'color_index' => { q: 'bl' }
    }
  end

  it 'is enumerable' do
    expect(described_class).to include(Enumerable)
  end

  context 'with index name keys' do
    it 'enumerates through the hits' do
      expect(result).to contain_exactly(
        a_hash_including('author' => 'Walter Isaacson', 'name' => 'Steve Jobs'),
        a_hash_including('name' => 'palm pixi plus'),
        a_hash_including('name' => 'blue', 'short_name' => 'blu'),
        a_hash_including('name' => 'black', 'short_name' => 'bla')
      )
    end
  end

  describe '#metadata' do
    it 'returns search metadata for the search' do
      expect(result.metadata).to eq({ 'offset' => 10, 'limit' => 5 })
    end
  end
end
