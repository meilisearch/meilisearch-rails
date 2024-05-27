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

