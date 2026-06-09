require 'support/mongo_models/citizen'

describe 'MongoDB record is created' do
  it 'is added to meilisearch' do
    john_wick = Citizen.create(name: 'John Wick', age: 40)

    AsyncHelper.wait_for_pending_tasks(index_uids: [Citizen.index_uid])

    expect(Citizen.search('John')).to eq([john_wick])
  end
end
