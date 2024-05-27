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

