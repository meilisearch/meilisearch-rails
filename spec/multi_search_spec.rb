require 'spec_helper'
require 'support/models/book'
require 'support/models/product'
require 'support/models/color'

describe 'multi-search' do
  before do
    [Book, Color, Product].each do |klass|
      klass.delete_all
      klass.clear_index!
    end

    Product.insert_all([
                         { name: 'palm pixi plus', href: 'ebay', tags: ['terrible'] },
                         { name: 'lg vortex', href: 'ebay', tags: ['decent'] },
                         { name: 'palmpre', href: 'ebay', tags: ['discontinued', 'worst phone ever'] }
                       ])
    Product.reindex!

    Color.insert_all([
                       { name: 'blue', short_name: 'blu', hex: 0x0000FF },
                       { name: 'black', short_name: 'bla', hex: 0x000000 },
                       { name: 'green', short_name: 'gre', hex: 0x00FF00 }
                     ])
    Color.reindex!

    Book.insert_all([
                      { name: 'Steve Jobs', author: 'Walter Isaacson' },
                      { name: 'Moby Dick', author: 'Herman Melville' }
                    ])
    Book.reindex!
  end

  let(:palm_pixi_plus) { Product.find_by name: 'palm pixi plus' }
  let(:steve_jobs) { Book.find_by name: 'Steve Jobs' }
  let(:blue) { Color.find_by name: 'blue' }
  let(:black) { Color.find_by name: 'black' }

  context 'with class keys' do
    it 'returns ORM records' do
      results = MeiliSearch::Rails.multi_search(
        Book => { q: 'Steve' },
        Product => { q: 'palm', limit: 1 },
        Color => { q: 'bl' }
      )

      expect(results.to_h).to match(
        Book => [steve_jobs],
        Product => [palm_pixi_plus],
        Color => contain_exactly(blue, black)
      )
    end
  end

  context 'with arbitrary keys' do
    context 'when index_uid is not present' do
      it 'assumes key is index and errors' do
        expect do
          MeiliSearch::Rails.multi_search(
            'test_group' => { q: 'Steve' }
          )
        end.to raise_error(MeiliSearch::ApiError)
      end
    end

    context 'when :index_uid is present' do
      it 'searches the correct index' do
        results = MeiliSearch::Rails.multi_search(
          'books' => { q: 'Steve', index_uid: Book.index.uid },
          'products' => { q: 'palm', index_uid: Product.index.uid, limit: 1 },
          'colors' => { q: 'bl', index_uid: Color.index.uid }
        )

        expect(results.to_h).to match(
          'books' => [a_hash_including('author' => 'Walter Isaacson', 'name' => 'Steve Jobs')],
          'products' => [a_hash_including('name' => 'palm pixi plus')],
          'colors' => contain_exactly(
            a_hash_including('name' => 'blue', 'short_name' => 'blu'),
            a_hash_including('name' => 'black', 'short_name' => 'bla')
          )
        )
      end

      it 'allows searching the same index n times' do
        index_uid = Color.index.uid

        results = MeiliSearch::Rails.multi_search(
          'dark_colors' => { q: 'black', index_uid: index_uid },
          'bright_colors' => { q: 'blue', index_uid: index_uid },
          'nature_colors' => { q: 'green', index_uid: index_uid }
        )

        expect(results.to_h).to match(
          'bright_colors' => [a_hash_including('name' => 'blue', 'short_name' => 'blu')],
          'dark_colors' => [a_hash_including('name' => 'black', 'short_name' => 'bla')],
          'nature_colors' => [a_hash_including('name' => 'green', 'short_name' => 'gre')]
        )
      end

      context 'when :class_name is also present' do
        it 'loads results from the correct models' do
          results = MeiliSearch::Rails.multi_search(
            'books' => { q: 'Steve', index_uid: Book.index.uid, class_name: 'Book' },
            'products' => { q: 'palm', limit: 1, index_uid: Product.index.uid, class_name: 'Product' },
            'colors' => { q: 'bl', index_uid: Color.index.uid, class_name: 'Color' }
          )

          expect(results.to_h).to match(
            'books' => [steve_jobs],
            'products' => [palm_pixi_plus],
            'colors' => contain_exactly(blue, black)
          )
        end
      end
    end
  end

  context 'with index name keys' do
    it 'returns hashes' do
      results = MeiliSearch::Rails.multi_search(
        Book.index.uid => { q: 'Steve' },
        Product.index.uid.to_sym => { q: 'palm', limit: 1 },
        Color.index.uid => { q: 'bl' }
      )

      expect(results.to_h).to match(
        Book.index.uid => [a_hash_including('author' => 'Walter Isaacson', 'name' => 'Steve Jobs')],
        Product.index.uid.to_sym => [a_hash_including('name' => 'palm pixi plus')],
        Color.index.uid => contain_exactly(
          a_hash_including('name' => 'blue', 'short_name' => 'blu'),
          a_hash_including('name' => 'black', 'short_name' => 'bla')
        )
      )
    end

    context 'when class_name is specified' do
      it 'returns ORM records' do
        results = MeiliSearch::Rails.multi_search(
          Book.index.uid => { q: 'Steve', class_name: 'Book' },
          Product.index.uid.to_sym => { q: 'palm', limit: 1, class_name: 'Product' },
          Color.index.uid => { q: 'bl', class_name: 'Color' }
        )

        expect(results.to_h).to match(
          Book.index.uid => [steve_jobs],
          Product.index.uid.to_sym => [palm_pixi_plus],
          Color.index.uid => contain_exactly(blue, black)
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

      expect(results.to_h).to match(
        Book => [steve_jobs],
        Product.index_uid => [palm_pixi_plus],
        Color.index.uid => contain_exactly(
          a_hash_including('name' => 'blue', 'short_name' => 'blu'),
          a_hash_including('name' => 'black', 'short_name' => 'bla')
        )
      )
    end
  end

  context 'with pagination' do
    it 'properly paginates each search' do
      MeiliSearch::Rails.configuration[:pagination_backend] = :kaminari

      results = MeiliSearch::Rails.multi_search(
        Book => { q: 'Steve' },
        Product => { q: 'palm', page: 1, hits_per_page: 1 },
        Color.index.uid => { q: 'bl', page: 1, 'hitsPerPage' => '1' }
      )

      expect(results.to_h).to match(
        Book => [steve_jobs],
        Product => [palm_pixi_plus],
        Color.index_uid => contain_exactly(
          a_hash_including('name' => 'black', 'short_name' => 'bla')
        )
      )

      MeiliSearch::Rails.configuration[:pagination_backend] = nil
    end
  end
end
