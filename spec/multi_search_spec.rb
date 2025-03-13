require 'spec_helper'
require 'support/models/book'
require 'support/models/product'
require 'support/models/color'

describe 'multi-search' do
  def reset_indexes
    [Book, Color, Product].each do |klass|
      klass.delete_all
      klass.clear_index!(true)
    end
  end

  before do
    reset_indexes

    Product.create! name: 'palm pixi plus', href: 'ebay', tags: ['terrible']
    Product.create! name: 'lg vortex', href: 'ebay', tags: ['decent']
    Product.create! name: 'palmpre', href: 'ebay', tags: ['discontinued', 'worst phone ever']
    Product.reindex!

    Color.create! name: 'blue', short_name: 'blu', hex: 0x0000FF
    Color.create! name: 'black', short_name: 'bla', hex: 0x000000
    Color.create! name: 'green', short_name: 'gre', hex: 0x00FF00

    Book.create! name: 'Steve Jobs', author: 'Walter Isaacson'
    Book.create! name: 'Moby Dick', author: 'Herman Melville'
  end

  let!(:palm_pixi_plus) { Product.find_by name: 'palm pixi plus' }
  let!(:steve_jobs) { Book.find_by name: 'Steve Jobs' }
  let!(:blue) { Color.find_by name: 'blue' }
  let!(:black) { Color.find_by name: 'black' }

  context 'with class keys' do
    it 'returns ORM records' do
      results = Meilisearch::Rails.multi_search(
        Book => { q: 'Steve' },
        Product => { q: 'palm', limit: 1 },
        Color => { q: 'bl' }
      )

      expect(results).to contain_exactly(
        steve_jobs, palm_pixi_plus, blue, black
      )
    end
  end

  context 'with arbitrary keys' do
    context 'when index_uid is not present' do
      it 'assumes key is index and errors' do
        expect do
          Meilisearch::Rails.multi_search(
            'test_group' => { q: 'Steve' }
          )
        end.to raise_error(Meilisearch::ApiError)
      end
    end

    context 'when :index_uid is present' do
      it 'searches the correct index' do
        results = Meilisearch::Rails.multi_search(
          'books' => { q: 'Steve', index_uid: Book.index.uid },
          'products' => { q: 'palm', index_uid: Product.index.uid, limit: 1 },
          'colors' => { q: 'bl', index_uid: Color.index.uid }
        )

        expect(results).to contain_exactly(
          a_hash_including('author' => 'Walter Isaacson', 'name' => 'Steve Jobs'),
          a_hash_including('name' => 'palm pixi plus'),
          a_hash_including('name' => 'blue', 'short_name' => 'blu'),
          a_hash_including('name' => 'black', 'short_name' => 'bla')
        )
      end

      it 'allows searching the same index n times' do
        index_uid = Color.index.uid

        results = Meilisearch::Rails.multi_search(
          'dark_colors' => { q: 'black', index_uid: index_uid },
          'bright_colors' => { q: 'blue', index_uid: index_uid },
          'nature_colors' => { q: 'green', index_uid: index_uid }
        )

        expect(results).to contain_exactly(
          a_hash_including('name' => 'blue', 'short_name' => 'blu'),
          a_hash_including('name' => 'black', 'short_name' => 'bla'),
          a_hash_including('name' => 'green', 'short_name' => 'gre')
        )
      end

      context 'when :class_name is also present' do
        it 'loads results from the correct models' do
          results = Meilisearch::Rails.multi_search(
            'books' => { q: 'Steve', index_uid: Book.index.uid, class_name: 'Book' },
            'products' => { q: 'palm', limit: 1, index_uid: Product.index.uid, class_name: 'Product' },
            'colors' => { q: 'bl', index_uid: Color.index.uid, class_name: 'Color' }
          )

          expect(results).to contain_exactly(
            steve_jobs, palm_pixi_plus, blue, black
          )
        end
      end
    end
  end

  context 'with index name keys' do
    it 'returns hashes' do
      results = Meilisearch::Rails.multi_search(
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
        results = Meilisearch::Rails.multi_search(
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
          Meilisearch::Rails.multi_search(
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
      results = Meilisearch::Rails.multi_search(
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

  context 'with pagination' do
    it 'properly paginates each search' do
      Meilisearch::Rails.configuration[:pagination_backend] = :kaminari

      results = Meilisearch::Rails.multi_search(
        Book => { q: 'Steve' },
        Product => { q: 'palm', page: 1, hits_per_page: 1 },
        Color.index.uid => { q: 'bl', page: 1, 'hitsPerPage' => '1' }
      )

      expect(results).to contain_exactly(
        steve_jobs, palm_pixi_plus,
        a_hash_including('name' => 'black', 'short_name' => 'bla')
      )

      Meilisearch::Rails.configuration[:pagination_backend] = nil
    end
  end

  context 'with collections' do
    it 'fetches items from the given collection' do
      results = MeiliSearch::Rails.multi_search(
        Product.index.uid => { q: 'palm', class_name: 'Product', collection: Product.where('tags LIKE "%terrible%"') },
        Color => { q: 'bl', collection: Color.where(short_name: 'bla') }
      )

      expect(results).to contain_exactly(
        black, palm_pixi_plus
      )
    end

    it 'infers the model' do
      results = MeiliSearch::Rails.multi_search(
        'colors' => { q: 'bl', collection: Color.all, index_uid: Color.index.uid }
      )

      expect(results.to_h['colors']).to contain_exactly(blue, black)
    end

    it 'infers the index as well as the model' do
      results = MeiliSearch::Rails.multi_search(
        'colors' => { q: 'bl', collection: Color }
      )

      expect(results.to_h['colors']).to contain_exactly(blue, black)
    end
  end
end
