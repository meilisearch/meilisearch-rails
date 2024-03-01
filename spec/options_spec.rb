require 'support/models/color'
require 'support/models/book'

describe 'meilisearch_options' do
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
