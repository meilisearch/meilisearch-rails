require 'support/async_helper'
require 'support/models/color'
require 'support/models/book'
require 'support/models/animals'
require 'support/models/people'
require 'support/models/vegetable'
require 'support/models/fruit'
require 'support/models/disabled_models'
require 'support/models/queued_models'

describe 'meilisearch_options' do
  describe ':index_uid' do
    it 'sets the index uid specified' do
      TestUtil.reset_people!
      People.create(first_name: 'Jane', last_name: 'Doe', card_number: 75_801_887)
      expect(People.index.uid).to eq("#{safe_index_uid('MyCustomPeople')}_test")
    end
  end

  describe ':primary_key' do
    it 'sets the primary key specified' do
      TestUtil.reset_people!
      People.create(first_name: 'Jane', last_name: 'Doe', card_number: 75_801_887)
      expect(People.index.fetch_info.primary_key).to eq('card_number')
    end
  end

  describe ':index_uid and :primary_key (shared index)' do
    it 'index uid is the same' do
      cat_index = Cat.index_uid
      dog_index = Dog.index_uid

      expect(cat_index).to eq(dog_index)
    end

    it 'searching a type only returns its own documents' do
      TestUtil.reset_animals!

      Dog.create!([{ name: 'Toby the Dog' }, { name: 'Felix the Dog' }])
      Cat.create!([{ name: 'Toby the Cat' }, { name: 'Felix the Cat' }, { name: 'roar' }])

      expect(Cat.search('felix')).to be_one
      expect(Cat.search('felix').first.name).to eq('Felix the Cat')
      expect(Dog.search('toby')).to be_one
      expect(Dog.search('Toby').first.name).to eq('Toby the Dog')
    end
  end

  describe ':if' do
    it 'only indexes the record in the valid indexes' do
      TestUtil.reset_books!

      Book.create! name: 'Steve Jobs', author: 'Walter Isaacson',
                   premium: true, released: true

      results = Book.search('steve')
      expect(results).to be_one

      results = Book.index(safe_index_uid('BookAuthor')).search('walter')
      expect(results['hits']).to be_one

      # premium -> not part of the public index
      results = Book.index(safe_index_uid('Book')).search('steve')
      expect(results['hits']).to be_empty
    end
  end

  describe ':unless' do
    it 'only indexes the record if it evaluates to false' do
      NestedItem.clear_index!(true)

      i1 = NestedItem.create hidden: false
      i2 = NestedItem.create hidden: true

      i1.children << NestedItem.create(hidden: true) << NestedItem.create(hidden: true)
      NestedItem.where(id: [i1.id, i2.id]).reindex!(Meilisearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)

      result = NestedItem.index.get_document(i1.id)
      expect(result['nb_children']).to eq(2)

      result = NestedItem.raw_search('')
      expect(result['hits'].size).to eq(1)

      if i2.respond_to? :update_attributes
        i2.update_attributes hidden: false # rubocop:disable Rails/ActiveRecordAliases
      else
        i2.update hidden: false
      end

      result = NestedItem.raw_search('')
      expect(result['hits'].size).to eq(2)
    end
  end

  describe ':auto_index' do
    it 'is enabled by default' do
      TestUtil.reset_colors!

      Color.create!(name: 'blue', short_name: 'b', hex: 0xFF0000)
      results = Color.raw_search('blue')
      expect(results['hits'].size).to eq(1)
      expect(results['estimatedTotalHits']).to eq(1)
    end
  end

  describe ':auto_remove' do
    context 'when false' do
      it 'does not remove document on destroy' do
        TestUtil.reset_people!

        joanna = People.create(first_name: 'Joanna', last_name: 'Mason', card_number: 75_801_888)
        AsyncHelper.await_last_task

        result = People.raw_search('Joanna')
        expect(result['hits']).to be_one

        joanna.destroy
        AsyncHelper.await_last_task

        result = People.raw_search('Joanna')
        expect(result['hits']).to be_one
      end
    end
  end

  describe ':disable_indexing' do
    it 'prevents indexing when disabled with a boolean' do
      # manually trigger index creation since indexing is disabled
      DisabledBoolean.index
      AsyncHelper.await_last_task

      DisabledBoolean.create name: 'foo'
      expect(DisabledBoolean.search('')).to be_empty
    end

    it 'prevents indexing when disabled with a proc' do
      # manually trigger index creation since indexing is disabled
      DisabledProc.index
      AsyncHelper.await_last_task

      DisabledProc.create name: 'foo'
      expect(DisabledProc.search('')).to be_empty
    end

    it 'prevents indexing when disabled with a symbol (method)' do
      # manually trigger index creation since indexing is disabled
      DisabledSymbol.index
      AsyncHelper.await_last_task

      DisabledSymbol.create name: 'foo'
      expect(DisabledSymbol.search('')).to be_empty
    end
  end

  describe ':enqueue' do
    context 'when configured with a proc' do
      it 'runs proc when created' do
        expect do
          EnqueuedDocument.create! name: 'hellraiser'
        end.to raise_error('enqueued hellraiser')
      end

      it 'does not run proc in without_auto_index block' do
        expect do
          EnqueuedDocument.without_auto_index do
            EnqueuedDocument.create! name: 'test'
          end
        end.not_to raise_error
      end

      it 'does not run proc when auto_index is disabled' do
        expect do
          DisabledEnqueuedDocument.create! name: 'test'
        end.not_to raise_error
      end

      context 'when :if is configured' do
        before do
          allow(Meilisearch::Rails::MSJob).to receive(:perform_later).and_return(nil)
          allow(Meilisearch::Rails::MSCleanUpJob).to receive(:perform_later).and_return(nil)
        end

        it 'does not try to enqueue an index job when :if option resolves to false' do
          doc = ConditionallyEnqueuedDocument.create! name: 'test', is_public: false

          expect(Meilisearch::Rails::MSJob).not_to have_received(:perform_later).with(doc, 'ms_index!')
        end

        it 'enqueues an index job when :if option resolves to true' do
          doc = ConditionallyEnqueuedDocument.create! name: 'test', is_public: true

          expect(Meilisearch::Rails::MSJob).to have_received(:perform_later).with(doc, 'ms_index!')
        end

        it 'does enqueue a remove_from_index despite :if option' do
          doc = ConditionallyEnqueuedDocument.create!(name: 'test', is_public: true)
          expect(Meilisearch::Rails::MSJob).to have_received(:perform_later).with(doc, 'ms_index!')

          doc.destroy!

          expect(Meilisearch::Rails::MSCleanUpJob).to have_received(:perform_later).with(doc.ms_entries)
        end
      end
    end
  end

  describe ':sanitize' do
    context 'when true' do
      it 'sanitizes attributes' do
        TestUtil.reset_books!

        Book.create! name: '"><img src=x onerror=alert(1)> hack0r',
                     author: '<script type="text/javascript">alert(1)</script>', premium: true, released: true

        b = Book.raw_search('hack')

        expect(b['hits'][0]).to include(
          'name' => '"&gt; hack0r',
          'author' => ''
        )
      end

      it 'keeps _formatted emphasis' do
        TestUtil.reset_books!

        Book.create! name: '"><img src=x onerror=alert(1)> hack0r',
                     author: '<script type="text/javascript">alert(1)</script>', premium: true, released: true

        b = Book.raw_search('hack', { attributes_to_highlight: ['*'] })

        expect(b['hits'][0]['_formatted']).to include(
          'name' => '"&gt; <em>hack</em>0r'
        )
      end
    end
  end

  describe ':raise_on_failure' do
    context 'when true' do
      it 'raises exception on failure' do
        expect do
          Fruit.search('', { filter: 'title = Nightshift' })
        end.to raise_error(Meilisearch::ApiError)
      end
    end

    context 'when set to false' do
      it 'fails without an exception' do
        expect do
          Vegetable.search('', { filter: 'title = Kale' })
        end.not_to raise_error
      end

      context 'in case of timeout' do
        let(:index_instance) { instance_double(Meilisearch::Index, settings: nil, update_settings: nil) }
        let(:slow_client) { instance_double(Meilisearch::Client, index: index_instance) }

        before do
          allow(slow_client).to receive(:create_index)
          allow(Meilisearch::Rails).to receive(:client).and_return(slow_client)
        end

        it 'does not raise error timeouts on reindex' do
          allow(index_instance).to receive(:add_documents).and_raise(Meilisearch::TimeoutError)

          expect do
            Vegetable.create(name: 'potato')
          end.not_to raise_error
        end

        it 'does not raise error timeouts on data addition' do
          allow(index_instance).to receive(:add_documents).and_return(nil)

          expect do
            Vegetable.ms_reindex!
          end.not_to raise_error
        end
      end
    end
  end
end
