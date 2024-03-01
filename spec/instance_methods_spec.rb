require 'support/models/book'

describe 'Instance methods' do
  describe '#ms_entries' do
    it 'includes conditionally enabled indexes' do
      book = Book.create!(
        name: 'Frankenstein', author: 'Mary Shelley',
        premium: false, released: true
      )

      expect(book.ms_entries).to contain_exactly(
        a_hash_including("index_uid" => safe_index_uid('SecuredBook')),
        a_hash_including("index_uid" => safe_index_uid('BookAuthor')),
        a_hash_including("index_uid" => safe_index_uid('Book')),
      )
    end

    it 'includes conditionally disabled indexes' do
      # non public book
      book = Book.create!(
        name: 'Frankenstein', author: 'Mary Shelley',
        premium: false, released: false
      )

      expect(book.ms_entries).to contain_exactly(
        a_hash_including("index_uid" => safe_index_uid('SecuredBook')),
        a_hash_including("index_uid" => safe_index_uid('BookAuthor')),
        # also includes book's id as if it was a public book
        a_hash_including("index_uid" => safe_index_uid('Book')),
      )
    end
  end

  describe '#ms_index!' do
    it 'returns array of tasks' do
      TestUtil.reset_books!

      moby_dick = Book.create! name: 'Moby Dick', author: 'Herman Melville', premium: false, released: true

      tasks = moby_dick.ms_index!

      expect(tasks).to contain_exactly(
        a_hash_including('uid'),
        a_hash_including('taskUid'),
        a_hash_including('taskUid')
      )
    end

    it 'throws error on non-persisted instances' do
      expect { Color.new(name: 'purple').index!(true) }.to raise_error(ArgumentError)
    end
  end

  describe '#ms_remove_from_index!' do
    it 'throws error on non-persisted instances' do
      expect { Color.new(name: 'purple').remove_from_index!(true) }.to raise_error(ArgumentError)
    end
  end
end
