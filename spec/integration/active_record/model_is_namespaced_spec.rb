require 'support/models/specialty_models'

describe 'When a record has associations' do
  it 'has an index name without :: hierarchy' do
    expect(Namespaced::Model.index_uid.include?('Namespaced_Model')).to be(true)
  end
end
