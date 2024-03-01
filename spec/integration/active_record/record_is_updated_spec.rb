require 'support/models/book'

describe 'When record is updated' do
  it 'automatically removes document from conditional indexes' do
    TestUtil.reset_books!

    # add a new public book which is public (not premium but released)
    book = Book.create! name: 'Public book', author: 'me', premium: false, released: true

    # should be searchable in the 'Book' index
    index = Book.index(safe_index_uid('Book'))
    results = index.search('Public book')
    expect(results['hits']).to be_one

    # update the book and make it non-public anymore (not premium, not released)
    book.update released: false

    # should be removed from the index
    results = index.search('Public book')
    expect(results['hits']).to be_empty
  end
end
