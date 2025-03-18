require 'support/mongo_models/citizen'

describe 'MongoDB record is created' do
  it 'is added to meilisearch' do
    john_wick = Citizen.create(name: 'John Wick', age: 40)

    AsyncHelper.await_last_task

    expect(Citizen.search('John')).to eq([john_wick])
  end
end
