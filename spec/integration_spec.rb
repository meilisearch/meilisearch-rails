require 'spec_helper'

describe 'Settings change detection' do
  it 'detects settings changes' do
    expect(Color.send(:meilisearch_settings_changed?, nil, {})).to be(true)
    expect(Color.send(:meilisearch_settings_changed?, {}, { 'searchable_attributes' => ['name'] })).to be(true)
    expect(Color.send(:meilisearch_settings_changed?, { 'searchable_attributes' => ['name'] },
                      { 'searchable_attributes' => %w[name hex] })).to be(true)
    expect(Color.send(:meilisearch_settings_changed?, { 'searchable_attributes' => ['name'] },
                      { 'ranking_rules' => ['words', 'typo', 'proximity', 'attribute', 'sort', 'exactness', 'hex:asc'] })).to be(true)
  end

  it 'does not detect settings changes' do
    expect(Color.send(:meilisearch_settings_changed?, {}, {})).to be(false)
    expect(Color.send(:meilisearch_settings_changed?, { 'searchableAttributes' => ['name'] },
                      { searchable_attributes: ['name'] })).to be(false)
    expect(Color.send(:meilisearch_settings_changed?,
                      { 'searchableAttributes' => ['name'], 'rankingRules' => ['words', 'typo', 'proximity', 'attribute', 'sort', 'exactness', 'hex:asc'] },
                      { 'ranking_rules' => ['words', 'typo', 'proximity', 'attribute', 'sort', 'exactness', 'hex:asc'] })).to be(false)
  end
end

describe 'NestedItem' do
  before(:all) do
    NestedItem.clear_index!(true)
  rescue StandardError
    # not fatal
  end

  it 'fetches attributes unscoped' do
    i1 = NestedItem.create hidden: false
    i2 = NestedItem.create hidden: true

    i1.children << NestedItem.create(hidden: true) << NestedItem.create(hidden: true)
    NestedItem.where(id: [i1.id, i2.id]).reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)

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

unless OLD_RAILS
  describe 'EnqueuedDocument' do
    it 'enqueues a job' do
      expect do
        EnqueuedDocument.create! name: 'hellraiser'
      end.to raise_error('enqueued hellraiser')
    end

    it 'does not enqueue a job inside no index block' do
      expect do
        EnqueuedDocument.without_auto_index do
          EnqueuedDocument.create! name: 'test'
        end
      end.not_to raise_error
    end
  end

  describe 'DisabledEnqueuedDocument' do
    it '#ms_index! returns an empty array' do
      doc = DisabledEnqueuedDocument.create! name: 'test'

      expect(doc.ms_index!).to be_empty
    end

    it 'does not try to enqueue a job' do
      expect do
        DisabledEnqueuedDocument.create! name: 'test'
      end.not_to raise_error
    end
  end

  describe 'ConditionallyEnqueuedDocument' do
    before do
      allow(MeiliSearch::Rails::MSJob).to receive(:perform_later).and_return(nil)
      allow(MeiliSearch::Rails::MSCleanUpJob).to receive(:perform_later).and_return(nil)
    end

    it 'does not try to enqueue an index job when :if option resolves to false' do
      doc = ConditionallyEnqueuedDocument.create! name: 'test', is_public: false

      expect(MeiliSearch::Rails::MSJob).not_to have_received(:perform_later).with(doc, 'ms_index!')
    end

    it 'enqueues an index job when :if option resolves to true' do
      doc = ConditionallyEnqueuedDocument.create! name: 'test', is_public: true

      expect(MeiliSearch::Rails::MSJob).to have_received(:perform_later).with(doc, 'ms_index!')
    end

    it 'does enqueue a remove_from_index despite :if option' do
      doc = ConditionallyEnqueuedDocument.create!(name: 'test', is_public: true)
      expect(MeiliSearch::Rails::MSJob).to have_received(:perform_later).with(doc, 'ms_index!')

      doc.destroy!

      expect(MeiliSearch::Rails::MSCleanUpJob).to have_received(:perform_later).with(doc.ms_entries)
    end
  end
end

describe 'Misconfigured Block' do
  it 'forces the meilisearch block' do
    expect do
      MisconfiguredBlock.reindex!
    end.to raise_error(ArgumentError)
  end
end

describe 'Songs' do
  before(:all) { MeiliSearch::Rails.configuration[:per_environment] = false }

  after(:all) { MeiliSearch::Rails.configuration[:per_environment] = true }

  it 'targets multiple indices' do
    Song.create!(name: 'Coconut nut', artist: 'Smokey Mountain', premium: false, released: true) # Only song supposed to be added to Songs index
    Song.create!(name: 'Smoking hot', artist: 'Cigarettes before lunch', premium: true, released: true)
    Song.create!(name: 'Floor is lava', artist: 'Volcano', premium: true, released: false)
    Song.index.wait_for_task(Song.index.tasks['results'].first['uid'])
    MeiliSearch::Rails.client.index(safe_index_uid('PrivateSongs')).wait_for_task(MeiliSearch::Rails.client.index(safe_index_uid('PrivateSongs')).tasks['results'].first['uid'])
    results = Song.search('', index: safe_index_uid('Songs'))
    expect(results.size).to eq(1)
    raw_results = Song.raw_search('', index: safe_index_uid('Songs'))
    expect(raw_results['hits'].size).to eq(1)
    results = Song.search('', index: safe_index_uid('PrivateSongs'))
    expect(results.size).to eq(3)
    raw_results = Song.raw_search('', index: safe_index_uid('PrivateSongs'))
    expect(raw_results['hits'].size).to eq(3)
  end
end

describe 'Raise on failure' do
  before { Vegetable.instance_variable_set('@ms_indexes', nil) }

  it 'raises on failure' do
    expect do
      Fruit.search('', { filter: 'title = Nightshift' })
    end.to raise_error(MeiliSearch::ApiError)
  end

  it 'does not raise on failure' do
    expect do
      Vegetable.search('', { filter: 'title = Kale' })
    end.not_to raise_error
  end

  context 'when Meilisearch server take too long to answer' do
    let(:index_instance) { instance_double(MeiliSearch::Index, settings: nil, update_settings: nil) }
    let(:slow_client) { instance_double(MeiliSearch::Client, index: index_instance) }

    before do
      allow(slow_client).to receive(:create_index)
      allow(MeiliSearch::Rails).to receive(:client).and_return(slow_client)
    end

    it 'does not raise error timeouts on reindex' do
      allow(index_instance).to receive(:add_documents).and_raise(MeiliSearch::TimeoutError)

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

# This changes the index uid of the People class as well, making tests unrandomizable
# context 'when a searchable attribute is not an attribute' do
#   let(:other_people_class) do
#     Class.new(People) do
#       def self.name
#         'People'
#       end
#     end
#   end

#   let(:logger) { instance_double('Logger', warn: nil) }

#   before do
#     allow(MeiliSearch::Rails).to receive(:logger).and_return(logger)

#     other_people_class.meilisearch index_uid: safe_index_uid('Others'), primary_key: :card_number do
#       attribute :first_name
#       searchable_attributes %i[first_name last_name]
#     end
#   end

#   it 'warns the user' do
#     expect(logger).to have_received(:warn).with(/meilisearch-rails.+last_name/)
#   end
# end

context "when have a internal class defined in the app's scope" do
  it 'does not raise NoMethodError' do
    Task.create(title: 'my task #1')

    expect do
      Task.search('task')
    end.not_to raise_error
  end
end

context 'when MeiliSearch calls are deactivated' do
  it 'is active by default' do
    expect(MeiliSearch::Rails).to be_active
  end

  describe '#deactivate!' do
    context 'without block' do
      before { MeiliSearch::Rails.deactivate! }

      after { MeiliSearch::Rails.activate! }

      it 'deactivates the requests and keep the state' do
        expect(MeiliSearch::Rails).not_to be_active
      end

      it 'responds with a black hole' do
        expect(MeiliSearch::Rails.client.foo.bar.now.nil.item.issue).to be_nil
      end

      it 'deactivates requests' do
        expect do
          Task.create(title: 'my task #1')
          Task.search('task')
        end.not_to raise_error
      end
    end

    context 'with a block' do
      it 'disables only around call' do
        MeiliSearch::Rails.deactivate! do
          expect(MeiliSearch::Rails).not_to be_active
        end

        expect(MeiliSearch::Rails).to be_active
      end

      it 'works even when the instance made calls earlier' do
        Task.destroy_all
        Task.create!(title: 'deactivated #1')

        MeiliSearch::Rails.deactivate! do
          # always 0 since the black hole will return the default values
          expect(Task.search('deactivated').size).to eq(0)
        end

        expect(MeiliSearch::Rails).to be_active
        expect(Task.search('#1').size).to eq(1)
      end

      it 'works in multi-threaded environments' do
        Threads.new(5, log: $stdout).assert(20) do |_i, _r|
          MeiliSearch::Rails.deactivate! do
            expect(MeiliSearch::Rails).not_to be_active
          end

          expect(MeiliSearch::Rails).to be_active
        end
      end
    end
  end
end
