require 'support/models/specialty_models'

describe 'When Meilisearch::Rails is included but not called' do
  it 'raises an error' do
    expect do
      MisconfiguredBlock.reindex!
    end.to raise_error(ArgumentError)
  end
end
