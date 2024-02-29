require 'support/sequel_models/book'

describe 'When sequel record is created' do
  before do
    SequelBook.clear_index!(true)
  end

  it 'indexes the book' do
    steve_jobs = SequelBook.create name: 'Steve Jobs', author: 'Walter Isaacson', premium: true, released: true
    results = SequelBook.search('steve')

    expect(results.size).to eq(1)
    expect(results[0].id).to eq(steve_jobs.id)
  end

  it 'does not override after hooks' do
    allow(SequelBook).to receive(:new).and_call_original
    SequelBook.create name: 'Steve Jobs', author: 'Walter Isaacson', premium: true, released: true
    expect(SequelBook).to have_received(:new).twice
  end
end
