require 'support/models/book'
require 'support/models/animals'

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

    context 'when models share an index' do
      it 'does not return instances of other models' do
        TestUtil.reset_animals!

        toby_dog = Dog.create!(name: 'Toby the Dog')
        taby_cat = Cat.create!(name: 'Taby the Cat')

        expect(toby_dog.ms_entries).to contain_exactly(
          a_hash_including('primary_key' => /dog_\d+/))

        expect(taby_cat.ms_entries).to contain_exactly(
          a_hash_including('primary_key' => /cat_\d+/))
      end
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
