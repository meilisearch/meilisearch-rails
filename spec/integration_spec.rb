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

