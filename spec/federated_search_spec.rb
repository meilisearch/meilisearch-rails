require 'spec_helper'
require 'support/async_helper'
require 'support/models/book'
require 'support/models/product'
require 'support/models/color'

describe 'federated-search' do
  before do
    [Book, Color, Product].each(&:delete_all)
    [Book, Color, Product].each(&:clear_index!)

    Product.insert_all([
                         { name: 'palm pixi plus', href: 'ebay', tags: ['terrible'] },
                         { name: 'lg vortex', href: 'ebay', tags: ['decent'] },
                         { name: 'palmpre', href: 'ebay', tags: ['discontinued', 'worst phone ever'] }
                       ])

    Color.insert_all([
                       { name: 'blue', short_name: 'blu', hex: 0x0000FF },
                       { name: 'black', short_name: 'bla', hex: 0x000000 },
                       { name: 'green', short_name: 'gre', hex: 0x00FF00 }
                     ])

    Book.insert_all([
                      { name: 'Steve Jobs', author: 'Walter Isaacson' },
                      { name: 'Moby Dick', author: 'Herman Melville' }
                    ])

    [Book, Color, Product].each(&:reindex!)
    AsyncHelper.await_last_task
  end

  let!(:products) do
    Product.all.index_by(&:name)
  end

  let!(:books) do
    Book.all.index_by(&:name)
  end

  let!(:colors) do
    Color.all.index_by(&:name)
  end

  context 'with queries passed as arrays' do
    it 'ranks better match above worse match' do
      results = Meilisearch::Rails.federated_search(
        queries: [
          { q: 'Steve', scope: Book.all },
          { q: 'black', scope: Color.all }
        ]
      )

      expect(results.first).to eq(colors['black'])
      expect(results.last).to eq(books['Steve Jobs'])
    end

    context 'when :index_uid is passed' do
      it 'takes precedence over other sources of index uids' do
        Meilisearch::Rails.client.create_index('temp_books')
        Meilisearch::Rails.client.swap_indexes(['temp_books', Book.index.uid]).await

        results = Meilisearch::Rails.federated_search(
          queries: [{ q: 'Moby', scope: Book.all, index_uid: 'temp_books' }]
        )

        expect(results).to contain_exactly(books['Moby Dick'])

        Meilisearch::Rails.client.delete_index('temp_books')
      end
    end

    context 'when :scope is passed' do
      context 'when :scope is a model' do
        it 'returns ORM records with inferred index names' do
          results = Meilisearch::Rails.federated_search(
            queries: [
              { q: 'Steve', scope: Book },
              { q: 'palm', scope: Product },
              { q: 'bl', scope: Color }
            ]
          )

          expect(results).to contain_exactly(
            books['Steve Jobs'], products['palmpre'], products['palm pixi plus'], colors['blue'], colors['black']
          )
        end
      end

      context 'when :scope is a Relation' do
        it 'returns results within scope' do
          results = Meilisearch::Rails.federated_search(
            queries: [
              { q: 'Steve', scope: Book },
              { q: 'palm', scope: Product.where(name: 'palmpre') },
              { q: 'bl', scope: Color }
            ]
          )

          expect(results).to contain_exactly(
            books['Steve Jobs'], products['palmpre'], colors['blue'], colors['black']
          )
        end
      end
    end

    context 'without :scope' do
      it 'returns raw hashes' do
        results = Meilisearch::Rails.federated_search(
          queries: [{ q: 'Steve', index_uid: Book.index.uid }]
        )

        expect(results).to contain_exactly(a_hash_including('name' => 'Steve Jobs'))
      end
    end
  end

  context 'with queries passed as a hash' do
    context 'when the keys are index names' do
      it 'loads the right models with :scope' do
        Meilisearch::Rails.client.create_index('temp_books').await
        Meilisearch::Rails.client.swap_indexes(['temp_books', Book.index.uid]).await

        results = Meilisearch::Rails.federated_search(
          queries: {
            'temp_books' => { q: 'Steve', scope: Book }
          }
        )

        expect(results).to contain_exactly(books['Steve Jobs'])

        Meilisearch::Rails.client.delete_index('temp_books')
      end

      it 'returns hashes without :scope' do
        results = Meilisearch::Rails.federated_search(
          queries: {
            Book.index.uid => { q: 'Steve' }
          }
        )

        expect(results).to contain_exactly(a_hash_including('name' => 'Steve Jobs'))
      end
    end

    context 'when the keys are models' do
      it 'loads the correct models' do
        results = Meilisearch::Rails.federated_search(
          queries: {
            Book => { q: 'Steve' }
          }
        )

        expect(results).to contain_exactly(books['Steve Jobs'])
      end

      it 'allows overriding index_uid' do
        Meilisearch::Rails.client.create_index('temp_books').await
        Meilisearch::Rails.client.swap_indexes(['temp_books', Book.index.uid]).await

        results = Meilisearch::Rails.federated_search(
          queries: {
            Book => { q: 'Steve', index_uid: 'temp_books' }
          }
        )

        expect(results).to contain_exactly(books['Steve Jobs'])

        Meilisearch::Rails.client.delete_index('temp_books')
      end
    end

    context 'when the keys are arbitrary' do
      it 'acts the same as if the keys were arrays' do
        Meilisearch::Rails.client.create_index('temp_books').await
        Meilisearch::Rails.client.swap_indexes(['temp_books', Book.index.uid]).await

        results = Meilisearch::Rails.federated_search(
          queries: {
            classics: { q: 'Moby', scope: Book, index_uid: 'temp_books' }
          }
        )

        expect(results).to contain_exactly(books['Moby Dick'])

        Meilisearch::Rails.client.delete_index('temp_books')
      end

      it 'requires :index_uid to search the correct index' do
        expect do
          Meilisearch::Rails.federated_search(
            queries: { all_books: { q: 'Moby', scope: Book } }
          )
        end.to raise_error(Meilisearch::ApiError).with_message(/Index `all_books` not found/)
      end
    end
  end

  describe 'warnings' do
    let(:logger) { instance_double('Logger', warn: nil) }

    before do
      allow(Meilisearch::Rails).to receive(:logger).and_return(logger)
    end

    it 'warns if query has pagination options, but completes the search anyway' do
      results = Meilisearch::Rails.federated_search(
        queries: [
          { q: 'Steve', scope: Book, limit: 1 },
          { q: 'No results please', scope: Book, offset: 1 },
          { q: 'No results please', scope: Book, hits_per_page: 1 },
          { q: 'No results please', scope: Book, page: 1 }
        ]
      )

      expect(logger).to have_received('warn').with(a_string_including('options have been removed: limit'))
      expect(logger).to have_received('warn').with(a_string_including('options have been removed: offset'))
      expect(logger).to have_received('warn').with(a_string_including('options have been removed: hits_per_page'))
      expect(logger).to have_received('warn').with(a_string_including('options have been removed: page'))

      expect(results).to contain_exactly(books['Steve Jobs'])
    end

    it 'warns if :scope model is not a meilisearch model' do
      results = Meilisearch::Rails.federated_search(
        queries: [{ q: 'Steve', scope: String }]
      )

      expect(logger).to have_received('warn').with(a_string_including('does not have an #index'))
      expect(results).to be_empty
    end

    it 'warns if :federation argument is nil, but completes search anyway' do
      # This would disable federated search if not caught
      results = Meilisearch::Rails.federated_search(
        queries: [{ q: 'Steve', scope: Book }],
        federation: nil
      )

      expect(logger).to have_received('warn').with(a_string_including('`nil` is an invalid `:federation` option.'))
      expect(results).to contain_exactly(books['Steve Jobs'])
    end
  end
end
