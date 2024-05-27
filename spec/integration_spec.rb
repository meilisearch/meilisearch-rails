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

describe 'proximity_precision' do
  before do
    stub_const(
      'OtherColor',
      Class.new do
        include ActiveModel::Model
        include MeiliSearch::Rails
      end
    )
  end

  context 'when the value is byWord' do
    before do
      OtherColor.meilisearch synchronize: true, index_uid: safe_index_uid('OtherColors') do
        proximity_precision 'byWord'
      end
    end

    it 'sets the value byWord to proximity precision' do
      AsyncHelper.await_last_task
      expect(OtherColor.index.get_settings['proximityPrecision']).to eq('byWord')
    end
  end

  context 'when the value is byAttribute' do
    before do
      OtherColor.meilisearch synchronize: true, index_uid: safe_index_uid('OtherColors') do
        proximity_precision 'byAttribute'
      end
    end

    it 'sets the value byAttribute to proximity precision' do
      OtherColor.index.get_settings # induce update_settings
      AsyncHelper.await_last_task
      expect(OtherColor.index.get_settings['proximityPrecision']).to eq('byAttribute')
    end
  end
end

