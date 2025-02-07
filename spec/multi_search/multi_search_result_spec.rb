require 'spec_helper'

describe Meilisearch::Rails::MultiSearchResult do # rubocop:todo RSpec/FilePath
  let(:raw_results) do
    {
      'results' => [
        { 'indexUid' => 'books_index',
          'hits' => [{ 'name' => 'Steve Jobs', 'id' => '3', 'author' => 'Walter Isaacson', 'premium' => nil, 'released' => nil, 'genre' => nil }],
          'query' => 'Steve', 'processingTimeMs' => 0, 'limit' => 20, 'offset' => 0, 'estimatedTotalHits' => 1 },
        { 'indexUid' => 'products_index',
          'hits' => [{ 'id' => '4', 'href' => 'ebay', 'name' => 'palm pixi plus' }],
          'query' => 'palm', 'processingTimeMs' => 0, 'limit' => 1, 'offset' => 0, 'estimatedTotalHits' => 2 },
        { 'indexUid' => 'color_index',
          'hits' => [
            { 'name' => 'black', 'id' => '5', 'short_name' => 'bla', 'hex' => 0 },
            { 'name' => 'blue', 'id' => '4', 'short_name' => 'blu', 'hex' => 255 }
          ],
          'query' => 'bl', 'processingTimeMs' => 0, 'limit' => 20, 'offset' => 0, 'estimatedTotalHits' => 2 }
      ]
    }
  end

  it 'is enumerable' do
    expect(described_class).to include(Enumerable)
  end

  context 'with index name keys' do
    subject(:result) { described_class.new(searches, raw_results) }

    let(:searches) do
      {
        'books_index' => { q: 'Steve' },
        'products_index' => { q: 'palm', limit: 1 },
        'color_index' => { q: 'bl' }
      }
    end

    it 'enumerates through the hits' do
      expect(result).to contain_exactly(
        a_hash_including('author' => 'Walter Isaacson', 'name' => 'Steve Jobs'),
        a_hash_including('name' => 'palm pixi plus'),
        a_hash_including('name' => 'blue', 'short_name' => 'blu'),
        a_hash_including('name' => 'black', 'short_name' => 'bla')
      )
    end

    it 'enumerates through the hits of each result with #each_result' do
      expect(result.each_result).to be_an(Enumerator)
      expect(result.each_result).to contain_exactly(
        ['books_index', contain_exactly(
          a_hash_including('author' => 'Walter Isaacson', 'name' => 'Steve Jobs')
        )],
        ['products_index', contain_exactly(
          a_hash_including('name' => 'palm pixi plus')
        )],
        ['color_index', contain_exactly(
          a_hash_including('name' => 'blue', 'short_name' => 'blu'),
          a_hash_including('name' => 'black', 'short_name' => 'bla')
        )]
      )
    end

    describe '#to_a' do
      it 'returns the hits' do
        expect(result.to_a).to contain_exactly(
          a_hash_including('author' => 'Walter Isaacson', 'name' => 'Steve Jobs'),
          a_hash_including('name' => 'palm pixi plus'),
          a_hash_including('name' => 'blue', 'short_name' => 'blu'),
          a_hash_including('name' => 'black', 'short_name' => 'bla')
        )
      end

      it 'aliases as #to_ary' do
        expect(result.method(:to_ary).original_name).to eq :to_a
      end
    end

    describe '#to_h' do
      it 'returns a hash of indexes and hits' do
        expect(result.to_h).to match(
          'books_index' => contain_exactly(
            a_hash_including('author' => 'Walter Isaacson', 'name' => 'Steve Jobs')
          ),
          'products_index' => contain_exactly(
            a_hash_including('name' => 'palm pixi plus')
          ),
          'color_index' => contain_exactly(
            a_hash_including('name' => 'blue', 'short_name' => 'blu'),
            a_hash_including('name' => 'black', 'short_name' => 'bla')
          )
        )
      end

      it 'is aliased as #to_hash' do
        expect(result.method(:to_hash).original_name).to eq :to_h
      end
    end

    describe '#metadata' do
      it 'returns search metadata for each result' do
        expect(result.metadata).to match(
          'books_index' => {
            'indexUid' => 'books_index',
            'query' => 'Steve', 'processingTimeMs' => 0, 'limit' => 20, 'offset' => 0, 'estimatedTotalHits' => 1
          },
          'products_index' => {
            'indexUid' => 'products_index',
            'query' => 'palm', 'processingTimeMs' => 0, 'limit' => 1, 'offset' => 0, 'estimatedTotalHits' => 2
          },
          'color_index' => {
            'indexUid' => 'color_index',
            'query' => 'bl', 'processingTimeMs' => 0, 'limit' => 20, 'offset' => 0, 'estimatedTotalHits' => 2
          }
        )
      end
    end
  end
end
