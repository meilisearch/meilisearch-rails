require 'support/models/book'
require 'support/models/color'

describe 'When record is updated' do
  it 'updates the changed attributes on the index' do
    TestUtil.reset_colors!
    purple = Color.create!(name: 'purple', short_name: 'p')
    expect(Color.search('purple')).to be_one
    expect(Color.search('pink')).to be_empty

    purple.update name: 'pink'
    expect(Color.search('purple')).to be_empty
    expect(Color.search('pink')).to be_one
  end

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

  context 'when attributes have not changed' do
    it 'does not call the API' do
      TestUtil.reset_people!

      jane = People.create(first_name: 'Jane', last_name: 'Doe', card_number: 75_801_887)

      expect do
        jane.update(first_name: 'Jane')
      end.not_to change(People.index.tasks['results'], :count)
    end
  end
end
