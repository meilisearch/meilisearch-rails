require 'support/models/color'
require 'support/models/book'
require 'support/models/animals'
require 'support/models/people'

describe 'meilisearch_options' do
  describe ':index_uid' do
    it 'sets the index uid specified' do
      TestUtil.reset_people!
      People.create(first_name: 'Jane', last_name: 'Doe', card_number: 75_801_887)
      expect(People.index.uid).to eq("#{safe_index_uid('MyCustomPeople')}_test")
    end
  end

  describe ':primary_key' do
    it 'sets the primary key specified' do
      TestUtil.reset_people!
      People.create(first_name: 'Jane', last_name: 'Doe', card_number: 75_801_887)
      expect(People.index.fetch_info.primary_key).to eq('card_number')
    end
  end

  describe ':index_uid and :primary_key (shared index)' do
    it 'index uid is the same' do
      cat_index = Cat.index_uid
      dog_index = Dog.index_uid

      expect(cat_index).to eq(dog_index)
    end

    it 'searching a type only returns its own documents' do
      TestUtil.reset_animals!

      Dog.create!([{ name: 'Toby the Dog' }, { name: 'Felix the Dog' }])
      Cat.create!([{ name: 'Toby the Cat' }, { name: 'Felix the Cat' }, { name: 'roar' }])

      expect(Cat.search('felix')).to be_one
      expect(Cat.search('felix').first.name).to eq('Felix the Cat')
      expect(Dog.search('toby')).to be_one
      expect(Dog.search('Toby').first.name).to eq('Toby the Dog')
    end
  end

  describe ':if' do
    it 'only indexes the record in the valid indexes' do
      TestUtil.reset_books!

      Book.create! name: 'Steve Jobs', author: 'Walter Isaacson',
                   premium: true, released: true

      results = Book.search('steve')
      expect(results).to be_one

      results = Book.index(safe_index_uid('BookAuthor')).search('walter')
      expect(results['hits']).to be_one

      # premium -> not part of the public index
      results = Book.index(safe_index_uid('Book')).search('steve')
      expect(results['hits']).to be_empty
    end
  end

  describe ':auto_index' do
    it 'is enabled by default' do
      TestUtil.reset_colors!

      Color.create!(name: 'blue', short_name: 'b', hex: 0xFF0000)
      results = Color.raw_search('blue')
      expect(results['hits'].size).to eq(1)
      expect(results['estimatedTotalHits']).to eq(1)
    end
  end

  describe ':auto_remove' do
    context 'when false' do
      it 'does not remove document on destroy' do
        TestUtil.reset_people!

        joanna = People.create(first_name: 'Joanna', last_name: 'Banana', card_number: 75_801_888)

        result = People.raw_search('Joanna')
        expect(result['hits']).to be_one

        joanna.destroy

        result = People.raw_search('Joanna')
        expect(result['hits']).to be_one
      end
    end
  end

  describe ':sanitize' do
    context 'when true' do
      it 'sanitizes attributes' do
        TestUtil.reset_books!

        Book.create! name: '"><img src=x onerror=alert(1)> hack0r',
                     author: '<script type="text/javascript">alert(1)</script>', premium: true, released: true

        b = Book.raw_search('hack')

        expect(b['hits'][0]).to include(
          'name' => '"&gt; hack0r',
          'author' => '',
        )
      end

      it 'keeps _formatted emphasis' do
        TestUtil.reset_books!

        Book.create! name: '"><img src=x onerror=alert(1)> hack0r',
                     author: '<script type="text/javascript">alert(1)</script>', premium: true, released: true

        b = Book.raw_search('hack', { attributes_to_highlight: ['*'] })

        expect(b['hits'][0]['_formatted']).to include(
          'name' => '"&gt; <em>hack</em>0r',
        )
      end
    end
  end
end
