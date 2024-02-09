require 'spec_helper'

describe 'multi-search' do # rubocop:todo RSpec/DescribeClass
  def reset_indexes
    [Book, Color, Product].each do |klass|
      klass.delete_all
      klass.index.delete_all_documents
    end
  end

  before(:all) { reset_indexes } # rubocop:todo RSpec/BeforeAfterAll

  after { reset_indexes }

  let!(:palm_pixi_plus) { Product.create!(name: 'palm pixi plus', href: 'ebay', tags: ['terrible']) }
  let!(:steve_jobs) { Book.create! name: 'Steve Jobs', author: 'Walter Isaacson' }
  let!(:blue) { Color.create!(name: 'blue', short_name: 'blu', hex: 0x0000FF) }
  let!(:black) { Color.create!(name: 'black', short_name: 'bla', hex: 0x000000) }

  before do
    Product.create! name: 'lg vortex', href: 'ebay', tags: ['decent']
    Product.create! name: 'palmpre', href: 'ebay', tags: ['discontinued', 'worst phone ever']
    Product.reindex!

    Color.create! name: 'green', short_name: 'gre', hex: 0x00FF00
    Book.create! name: 'Moby Dick', author: 'Herman Melville'
  end

  context 'with class keys' do
    it 'returns ORM records' do
      results = MeiliSearch::Rails.multi_search(
        Book => { q: 'Steve' },
        Product => { q: 'palm', limit: 1 },
        Color => { q: 'bl' }
      )

      expect(results).to contain_exactly(
        steve_jobs, palm_pixi_plus, blue, black
      )
    end
  end

  context 'with index name keys' do
    it 'returns hashes' do
      results = MeiliSearch::Rails.multi_search(
        Book.index.uid => { q: 'Steve' },
        Product.index.uid.to_sym => { q: 'palm', limit: 1 },
        Color.index.uid => { q: 'bl' }
      )

      expect(results).to contain_exactly(
        a_hash_including('author' => 'Walter Isaacson', 'name' => 'Steve Jobs'),
        a_hash_including('name' => 'palm pixi plus'),
        a_hash_including('name' => 'blue', 'short_name' => 'blu'),
        a_hash_including('name' => 'black', 'short_name' => 'bla')
      )
    end

    context 'when class_name is specified' do
      it 'returns ORM records' do
        results = MeiliSearch::Rails.multi_search(
          Book.index.uid => { q: 'Steve', class_name: 'Book' },
          Product.index.uid.to_sym => { q: 'palm', limit: 1, class_name: 'Product' },
          Color.index.uid => { q: 'bl', class_name: 'Color' }
        )

        expect(results).to contain_exactly(
          steve_jobs, palm_pixi_plus, blue, black
        )
      end

      it 'throws error if class cannot be found' do
        expect do
          MeiliSearch::Rails.multi_search(
            Book.index.uid => { q: 'Steve', class_name: 'Book' },
            Product.index.uid.to_sym => { q: 'palm', limit: 1, class_name: 'ProductOfCapitalism' },
            Color.index.uid => { q: 'bl', class_name: 'Color' }
          )
        end.to raise_error(NameError)
      end
    end
  end

  context 'with a mixture of symbol and class keys' do
    it 'returns a mixture of ORM records and hashes' do
      results = MeiliSearch::Rails.multi_search(
        Book => { q: 'Steve' },
        Product.index.uid => { q: 'palm', limit: 1, class_name: 'Product' },
        Color.index.uid => { q: 'bl' }
      )

      expect(results).to contain_exactly(
        steve_jobs, palm_pixi_plus,
        a_hash_including('name' => 'blue', 'short_name' => 'blu'),
        a_hash_including('name' => 'black', 'short_name' => 'bla')
      )
    end
  end
end
