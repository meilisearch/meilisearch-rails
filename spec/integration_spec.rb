require 'spec_helper'

describe 'SequelBook' do
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
    expect(SequelBook).to receive(:new).twice.and_call_original
    SequelBook.create name: 'Steve Jobs', author: 'Walter Isaacson', premium: true, released: true
  end
end

if defined?(ActiveModel::Serializer)
  describe 'SerializedDocument' do
    before(:all) do
      SerializedDocument.clear_index!(true)
    end

    it 'pushes the name but not the other attribute' do
      o = SerializedDocument.new name: 'test', skip: 'skip me'
      attributes = SerializedDocument.meilisearch_settings.get_attributes(o)
      expect(attributes).to eq({ name: 'test' })
    end
  end
end

describe 'Encoding' do
  before(:all) do
    EncodedString.clear_index!(true)
  end

  it 'converts to utf-8' do
    EncodedString.create!
    results = EncodedString.raw_search ''
    expect(results['hits'].size).to eq(1)
    expect(results['hits'].first['value']).to eq("\xC2\xA0\xE2\x80\xA2\xC2\xA0".force_encoding('utf-8'))
  end
end

describe 'Settings change detection' do
  it 'detects settings changes' do
    expect(Color.send(:meilisearch_settings_changed?, nil, {})).to be(true)
    expect(Color.send(:meilisearch_settings_changed?, {}, { 'searchable_attributes' => ['name'] })).to be(true)
    expect(Color.send(:meilisearch_settings_changed?, { 'searchable_attributes' => ['name'] },
                      { 'searchable_attributes' => %w[name hex] })).to be(true)
    expect(Color.send(:meilisearch_settings_changed?, { 'searchable_attributes' => ['name'] },
                      { 'ranking_rules' => ['words', 'typo', 'proximity', 'attribute', 'sort', 'exactness', 'hex:asc'] })).to be(true)
  end

  it 'does not detect settings changes' do
    expect(Color.send(:meilisearch_settings_changed?, {}, {})).to be(false)
    expect(Color.send(:meilisearch_settings_changed?, { 'searchableAttributes' => ['name'] },
                      { searchable_attributes: ['name'] })).to be(false)
    expect(Color.send(:meilisearch_settings_changed?,
                      { 'searchableAttributes' => ['name'], 'rankingRules' => ['words', 'typo', 'proximity', 'attribute', 'sort', 'exactness', 'hex:asc'] },
                      { 'ranking_rules' => ['words', 'typo', 'proximity', 'attribute', 'sort', 'exactness', 'hex:asc'] })).to be(false)
  end
end

describe 'Attributes change detection' do
  it 'detects attribute changes' do
    color = Color.new name: 'dark-blue', short_name: 'blue'

    expect(Color.ms_must_reindex?(color)).to be(true)
    color.save
    expect(Color.ms_must_reindex?(color)).to be(false)

    color.hex = 123_456
    expect(Color.ms_must_reindex?(color)).to be(false)

    color.not_indexed = 'strstr'
    expect(Color.ms_must_reindex?(color)).to be(false)
    color.name = 'red'
    expect(Color.ms_must_reindex?(color)).to be(true)
    color.delete
  end

  it 'detects attribute changes even in a transaction' do
    color = Color.new name: 'dark-blue', short_name: 'blue'
    color.save
    expect(color.instance_variable_get('@ms_must_reindex')).to be_nil
    Color.transaction do
      color.name = 'red'
      color.save
      color.not_indexed = 'strstr'
      color.save
      expect(color.instance_variable_get('@ms_must_reindex')).to be(true)
    end
    expect(color.instance_variable_get('@ms_must_reindex')).to be_nil
    color.delete
  end

  it 'detects change with ms_dirty? method' do
    ebook = Ebook.new name: 'My life', author: 'Myself', premium: false, released: true
    expect(Ebook.ms_must_reindex?(ebook)).to be(true) # Because it's defined in ms_dirty? method
    ebook.current_time = 10
    ebook.published_at = 8
    expect(Ebook.ms_must_reindex?(ebook)).to be(true)
    ebook.published_at = 12
    expect(Ebook.ms_must_reindex?(ebook)).to be(false)
  end
end

describe 'Namespaced::Model' do
  before(:all) do
    Namespaced::Model.index.delete_all_documents!
  end

  it 'has an index name without :: hierarchy' do
    expect(Namespaced::Model.index_uid.include?('Namespaced_Model')).to be(true)
  end

  it 'uses the block to determine attribute\'s value' do
    m = Namespaced::Model.new(another_private_value: 2)
    attributes = Namespaced::Model.meilisearch_settings.get_attributes(m)
    expect(attributes['customAttr']).to eq(42)
    expect(attributes['myid']).to eq(m.id)
  end

  it 'always updates when there is no custom _changed? function' do
    m = Namespaced::Model.new(another_private_value: 2)
    m.save
    results = Namespaced::Model.search('42')
    expect(results.size).to eq(1)
    expect(results[0].id).to eq(m.id)

    m.another_private_value = 5
    m.save

    results = Namespaced::Model.search('42')
    expect(results.size).to eq(0)

    results = Namespaced::Model.search('45')
    expect(results.size).to eq(1)
    expect(results[0].id).to eq(m.id)
  end
end

describe 'NestedItem' do
  before(:all) do
    NestedItem.clear_index!(true)
  rescue StandardError
    # not fatal
  end

  it 'fetches attributes unscoped' do
    i1 = NestedItem.create hidden: false
    i2 = NestedItem.create hidden: true

    i1.children << NestedItem.create(hidden: true) << NestedItem.create(hidden: true)
    NestedItem.where(id: [i1.id, i2.id]).reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)

    result = NestedItem.index.get_document(i1.id)
    expect(result['nb_children']).to eq(2)

    result = NestedItem.raw_search('')
    expect(result['hits'].size).to eq(1)

    if i2.respond_to? :update_attributes
      i2.update_attributes hidden: false # rubocop:disable Rails/ActiveRecordAliases
    else
      i2.update hidden: false
    end

    result = NestedItem.raw_search('')
    expect(result['hits'].size).to eq(2)
  end
end

describe 'Posts' do
  before(:all) do
    Post.clear_index!(true)
  end

  it 'eagerly loads associations' do
    post1 = Post.new(title: 'foo')
    post1.comments << Comment.new(body: 'one')
    post1.comments << Comment.new(body: 'two')
    post1.save!

    post2 = Post.new(title: 'bar')
    post2.comments << Comment.new(body: 'three')
    post2.comments << Comment.new(body: 'four')
    post2.save!

    assert_queries(2) do
      Post.reindex!
    end
  end
end

describe 'Colors' do
  before do
    Color.clear_index!(true)
    Color.delete_all
  end

  it 'is synchronous' do
    c = Color.new
    c.valid?
    expect(c.send(:ms_synchronous?)).to be(true)
  end

  it 'auto indexes' do
    blue = Color.create!(name: 'blue', short_name: 'b', hex: 0xFF0000)
    results = Color.search('blue')
    expect(results.size).to eq(1)
    expect(results).to include(blue)
  end

  it 'returns facets distribution' do
    Color.create!(name: 'blue', short_name: 'b', hex: 0xFF0000)
    results = Color.search('', { facets: ['short_name'] })
    expect(results.raw_answer).not_to be_nil
    expect(results.facets_distribution).not_to be_nil
    expect(results.facets_distribution.size).to eq(1)
    expect(results.facets_distribution['short_name']['b']).to eq(1)
  end

  it 'is raw searchable' do
    Color.create!(name: 'blue', short_name: 'b', hex: 0xFF0000)
    results = Color.raw_search('blue')
    expect(results['hits'].size).to eq(1)
    expect(results['estimatedTotalHits']).to eq(1)
  end

  it 'is able to temporarily disable auto-indexing' do
    Color.without_auto_index do
      Color.create!(name: 'blue', short_name: 'b', hex: 0xFF0000)
    end
    expect(Color.search('blue').size).to eq(0)
    Color.reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
    expect(Color.search('blue').size).to eq(1)
  end

  it 'is not searchable with non-searchable fields' do
    Color.create!(name: 'blue', short_name: 'x', hex: 0xFF0000)
    results = Color.search('x')
    expect(results.size).to eq(0)
  end

  it 'ranks with custom hex' do
    Color.create!(name: 'red', short_name: 'r3', hex: 3)
    Color.create!(name: 'red', short_name: 'r1', hex: 1)
    Color.create!(name: 'red', short_name: 'r2', hex: 2)
    results = Color.search('red')
    expect(results.size).to eq(3)
    expect(results[0].hex).to eq(1)
    expect(results[1].hex).to eq(2)
    expect(results[2].hex).to eq(3)
  end

  it 'updates the index if the attribute changed' do
    purple = Color.create!(name: 'purple', short_name: 'p')
    expect(Color.search('purple').size).to eq(1)
    expect(Color.search('pink').size).to eq(0)
    purple.name = 'pink'
    purple.save
    expect(Color.search('purple').size).to eq(0)
    expect(Color.search('pink').size).to eq(1)
  end

  it 'uses the specified scope' do
    Color.create!(name: 'red', short_name: 'r3', hex: 3)
    Color.create!(name: 'red', short_name: 'r1', hex: 1)
    Color.create!(name: 'red', short_name: 'r2', hex: 2)
    Color.create!(name: 'purple', short_name: 'p')
    Color.clear_index!(true)
    Color.where(name: 'red').reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
    expect(Color.search('').size).to eq(3)
    Color.clear_index!(true)
    Color.where(id: Color.first.id).reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
    expect(Color.search('').size).to eq(1)
  end

  it 'has a Rails env-based index name' do
    expect(Color.index_uid).to eq(safe_index_uid('Color') + "_#{Rails.env}")
  end

  it 'includes _formatted object' do
    Color.create!(name: 'green', short_name: 'b', hex: 0xFF0000)
    results = Color.search('gre')
    expect(results.size).to eq(1)
    expect(results[0].formatted).not_to be_nil
  end

  it 'indexes an array of documents' do
    json = Color.raw_search('')
    Color.index_documents Color.limit(1), true # reindex last color, `limit` is incompatible with the reindex! method
    expect(json['hits'].count).to eq(Color.raw_search('')['hits'].count)
  end

  it 'does not index non-saved document' do
    expect { Color.new(name: 'purple').index!(true) }.to raise_error(ArgumentError)
    expect { Color.new(name: 'purple').remove_from_index!(true) }.to raise_error(ArgumentError)
  end

  it 'searches with filter' do
    Color.create!(name: 'blue', short_name: 'blu', hex: 0x0000FF)
    black = Color.create!(name: 'black', short_name: 'bla', hex: 0x000000)
    Color.create!(name: 'green', short_name: 'gre', hex: 0x00FF00)
    facets = Color.search('bl', { filter: ['short_name = bla'] })
    expect(facets.size).to eq(1)
    expect(facets).to include(black)
  end

  it 'searches with sorting' do
    Color.delete_all

    blue = Color.create!(name: 'blue', short_name: 'blu', hex: 0x0000FF)
    black = Color.create!(name: 'black', short_name: 'bla', hex: 0x000000)
    green = Color.create!(name: 'green', short_name: 'gre', hex: 0x00FF00)

    facets = Color.search('*', { sort: ['name:asc'] })

    expect(facets).to eq([black, blue, green])
  end

  it 'has maxValuesPerFacet set' do
    expect(Color.ms_index.get_settings.dig('faceting', 'maxValuesPerFacet')).to eq(20)
  end
end

describe 'An imaginary store' do
  before(:all) do
    Product.clear_index!(true)

    # Google products
    @blackberry = Product.create!(name: 'blackberry', href: 'google', tags: ['decent', 'businessmen love it'])
    @nokia = Product.create!(name: 'nokia', href: 'google', tags: ['decent'])

    # Amazon products
    @android = Product.create!(name: 'android', href: 'amazon', tags: ['awesome'])
    @samsung = Product.create!(name: 'samsung', href: 'amazon', tags: ['decent'])
    @motorola = Product.create!(name: 'motorola', href: 'amazon', tags: ['decent'],
                                description: 'Not sure about features since I\'ve never owned one.')

    # Ebay products
    @palmpre = Product.create!(name: 'palmpre', href: 'ebay', tags: ['discontinued', 'worst phone ever'])
    @palm_pixi_plus = Product.create!(name: 'palm pixi plus', href: 'ebay', tags: ['terrible'])
    @lg_vortex = Product.create!(name: 'lg vortex', href: 'ebay', tags: ['decent'])
    @t_mobile = Product.create!(name: 't mobile', href: 'ebay', tags: ['terrible'])

    # Yahoo products
    @htc = Product.create!(name: 'htc', href: 'yahoo', tags: ['decent'])
    @htc_evo = Product.create!(name: 'htc evo', href: 'yahoo', tags: ['decent'])
    @ericson = Product.create!(name: 'ericson', href: 'yahoo', tags: ['decent'])

    # Apple products
    @iphone = Product.create!(name: 'iphone', href: 'apple', tags: ['awesome', 'poor reception'],
                              description: 'Puts even more features at your fingertips')
    @macbook = Product.create!(name: 'macbookpro', href: 'apple')

    # Unindexed products
    @sekrit = Product.create!(name: 'super sekrit', href: 'amazon', release_date: Time.now + 1.day)
    @no_href = Product.create!(name: 'super sekrit too; missing href')

    # Subproducts
    @camera = Camera.create!(name: 'canon eos rebel t3', href: 'canon')

    100.times { Product.create!(name: 'crapoola', href: 'crappy', tags: ['crappy']) }

    @products_in_database = Product.all

    Product.reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
  end

  it 'is not synchronous' do
    p = Product.new
    p.valid?

    expect(p).not_to be_ms_synchronous
  end

  it 'is able to reindex manually' do
    results_before_clearing = Product.raw_search('')
    expect(results_before_clearing['hits'].size).not_to be(0)
    Product.clear_index!(true)
    results = Product.raw_search('')
    expect(results['hits'].size).to be(0)
    Product.reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
    results_after_reindexing = Product.raw_search('')
    expect(results_after_reindexing['hits'].size).not_to be(0)
    expect(results_before_clearing['hits'].size).to be(results_after_reindexing['hits'].size)
  end

  describe 'basic searching' do
    it 'finds the iphone' do
      results = Product.search('iphone')
      expect(results.size).to eq(1)
      expect(results).to include(@iphone)
    end

    it 'searches case insensitively' do
      results = Product.search('IPHONE')
      expect(results.size).to eq(1)
      expect(results).to include(@iphone)
    end

    it 'finds all amazon products' do
      results = Product.search('amazon')
      expect(results.size).to eq(3)
      expect(results).to include(@android, @samsung, @motorola)
    end

    it 'finds all "palm" phones with wildcard word search' do
      results = Product.search('pal')
      expect(results.size).to eq(2)
      expect(results).to include(@palmpre, @palm_pixi_plus)
    end

    it 'searches multiple words from the same field' do
      results = Product.search('palm pixi plus')
      expect(results.size).to eq(1)
      expect(results).to include(@palm_pixi_plus)
    end

    it 'finds using phrase search' do
      results = Product.search('coco "palm"')
      expect(results.size).to eq(1)
      expect(results).to include(@palm_pixi_plus)
    end

    it 'narrows the results by searching across multiple fields' do
      results = Product.search('apple iphone')
      expect(results.size).to eq(2)
      expect(results).to include(@iphone)
    end

    it 'does not search on non-indexed fields' do
      results = Product.search('features')
      expect(results.size).to eq(0)
    end

    it 'deletes the associated record' do
      ipad = Product.create!(name: 'ipad', href: 'apple', tags: ['awesome', 'great battery'],
                             description: 'Big screen')

      ipad.index!(true)
      results = Product.search('ipad')
      expect(results.size).to eq(1)

      ipad.destroy
      results = Product.search('ipad')
      expect(results.size).to eq(0)
    end

    context 'when a document cannot be found in ActiveRecord' do
      it 'does not throw an exception' do
        Product.index.add_documents!(@palmpre.attributes.merge(id: -1))
        expect { Product.search('pal').to_json }.not_to raise_error
        Product.index.delete_document!(-1)
      end

      it 'returns the other results if those are still available locally' do
        Product.index.add_documents!(@palmpre.attributes.merge(id: -1))
        expect(JSON.parse(Product.search('pal').to_json).size).to eq(2)
        Product.index.delete_document!(-1)
      end
    end

    it 'does not duplicate an already indexed record' do
      expect(Product.search('nokia').size).to eq(1)
      @nokia.index!
      expect(Product.search('nokia').size).to eq(1)
      @nokia.index!
      @nokia.index!
      expect(Product.search('nokia').size).to eq(1)
    end

    it 'does not return products that are not indexable' do
      @sekrit.index!
      @no_href.index!
      results = Product.search('sekrit')
      expect(results.size).to eq(0)
    end

    it 'includes items belong to subclasses' do
      @camera.index!
      results = Product.search('eos rebel')
      expect(results.size).to eq(1)
      expect(results).to include(@camera)
    end

    it 'deletes a not-anymore-indexable product' do
      results = Product.search('sekrit')
      expect(results.size).to eq(0)

      @sekrit.release_date = Time.now - 1.day
      @sekrit.save!
      @sekrit.index!(true)
      results = Product.search('sekrit')
      expect(results.size).to eq(1)

      @sekrit.release_date = Time.now + 1.day
      @sekrit.save!
      @sekrit.index!(true)
      results = Product.search('sekrit')
      expect(results.size).to eq(0)
    end

    it 'finds using synonyms' do
      expect(Product.search('pomme').size).to eq(Product.search('apple').size)
      expect(Product.search('m_b_p').size).to eq(Product.search('macbookpro').size)
    end
  end
end

describe 'MongoDocument' do
  it 'does not have method conflicts' do
    expect { MongoDocument.reindex! }.to raise_error(NameError)
    expect { MongoDocument.new.index! }.to raise_error(NameError)
    MongoDocument.ms_reindex!
    MongoDocument.create(name: 'mongo').ms_index!
  end
end

describe 'Book' do
  before do
    Book.clear_index!(true)
    Book.index(safe_index_uid('BookAuthor')).delete_all_documents
    Book.index(safe_index_uid('Book')).delete_all_documents
  end

  it 'returns array of tasks on #ms_index!' do
    moby_dick = Book.create! name: 'Moby Dick', author: 'Herman Melville', premium: false, released: true

    tasks = moby_dick.ms_index!

    expect(tasks).to contain_exactly(
      a_hash_including('uid'),
      a_hash_including('taskUid'),
      a_hash_including('taskUid')
    )
  end

  it 'indexes the book in 2 indexes of 3' do
    steve_jobs = Book.create! name: 'Steve Jobs', author: 'Walter Isaacson', premium: true, released: true
    results = Book.search('steve')
    expect(results.size).to eq(1)
    expect(results).to include(steve_jobs)

    index_author = Book.index(safe_index_uid('BookAuthor'))
    expect(index_author).not_to be_nil
    results = index_author.search('steve')
    expect(results['hits'].length).to eq(0)
    results = index_author.search('walter')
    expect(results['hits'].length).to eq(1)

    # premium -> not part of the public index
    index_book = Book.index(safe_index_uid('Book'))
    expect(index_book).not_to be_nil
    results = index_book.search('steve')
    expect(results['hits'].length).to eq(0)
  end

  it 'sanitizes attributes' do
    _hack = Book.create! name: '"><img src=x onerror=alert(1)> hack0r',
                         author: '<script type="text/javascript">alert(1)</script>', premium: true, released: true
    b = Book.raw_search('hack', { attributes_to_highlight: ['*'] })
    expect(b['hits'].length).to eq(1)
    begin
      expect(b['hits'][0]['name']).to eq('"> hack0r').and_raise(StandardError)
      expect(b['hits'][0]['author']).to eq('alert(1)')
      expect(b['hits'][0]['_formatted']['name']).to eq('"> <em>hack</em>0r')
    rescue StandardError
      # rails 4.2's sanitizer
      begin
        expect(b['hits'][0]['name']).to eq('&quot;&gt; hack0r').and_raise(StandardError)
        expect(b['hits'][0]['author']).to eq('')
        expect(b['hits'][0]['_formatted']['name']).to eq('&quot;&gt; <em>hack</em>0r')
      rescue StandardError
        # jruby
        expect(b['hits'][0]['name']).to eq('"&gt; hack0r')
        expect(b['hits'][0]['author']).to eq('')
        expect(b['hits'][0]['_formatted']['name']).to eq('"&gt; <em>hack</em>0r')
      end
    end
  end

  it 'handles removal in an extra index' do
    # add a new public book which (not premium but released)
    book = Book.create! name: 'Public book', author: 'me', premium: false, released: true

    # should be searchable in the 'Book' index
    index = Book.index(safe_index_uid('Book'))
    results = index.search('Public book')
    expect(results['hits'].size).to eq(1)

    # update the book and make it non-public anymore (not premium, not released)
    book.update released: false

    # should be removed from the index
    results = index.search('Public book')
    expect(results['hits'].size).to eq(0)
  end

  it 'uses the per_environment option in the additional index as well' do
    index = Book.index(safe_index_uid('Book'))
    expect(index.uid).to eq("#{safe_index_uid('Book')}_#{Rails.env}")
  end

  it 'searches with one typo min size' do
    Book.create! name: 'The Lord of the Rings', author: 'me', premium: false, released: true
    results = Book.search('Lrod')
    expect(results.size).to eq(0)

    results = Book.search('Rnigs')
    expect(results.size).to eq(1)
  end

  it 'searches with two typo min size' do
    Book.create! name: 'Dracula', author: 'me', premium: false, released: true
    results = Book.search('Darclua')
    expect(results.size).to eq(0)

    Book.create! name: 'Frankenstein', author: 'me', premium: false, released: true
    results = Book.search('Farnkenstien')
    expect(results.size).to eq(1)
  end

  describe '#ms_entries' do
    it 'returns all 3 indexes for a public book' do
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

    it 'returns all 3 indexes for a non-public book' do
      book = Book.create!(
        name: 'Frankenstein', author: 'Mary Shelley',
        premium: false, released: false
      )

      expect(book.ms_entries).to contain_exactly(
        a_hash_including("index_uid" => safe_index_uid('SecuredBook')),
        a_hash_including("index_uid" => safe_index_uid('BookAuthor')),
        a_hash_including("index_uid" => safe_index_uid('Book')),
      )
    end
  end

  it 'returns facets using max values per facet' do
    10.times do
      Book.create! name: Faker::Book.title, author: Faker::Book.author, genre: Faker::Book.genre
    end

    genres = Book.distinct.pluck(:genre)

    results = Book.search('', { facets: ['genre'] })

    expect(genres.size).to be > 3
    expect(results.facets_distribution['genre'].size).to eq(3)
  end

  it 'does not error on facet_search' do
    genres = %w[Legend Fiction Crime].cycle
    authors = %w[A B C].cycle

    5.times do
      Book.create! name: Faker::Book.title, author: authors.next, genre: genres.next
    end

    expect do
      Book.index.facet_search('genre', 'Fic', filter: 'author = A')
      Book.index.facet_search('genre', filter: 'author = A')
      Book.index.facet_search('genre')
    end.not_to raise_error
  end

  context 'with Marshal serialization' do
    let(:found_books) { Book.search('*') }
    let(:marshaled_books) { Marshal.dump(found_books) }

    it 'returns all books in the marshaled format' do
      # Perform the search and marshal the results
      expect(marshaled_books).to be_present

      # Load the marshaled data and check the content
      loaded_books = Marshal.load(marshaled_books)
      expect(loaded_books).to match_array(found_books)
    end
  end

  context 'with Rails caching' do
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
    let(:cache) { Rails.cache }

    let(:search_query) { '*' }
    let(:cache_key) { "book_search:#{search_query}" }

    before do
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear
    end

    it 'caches the search results' do
      # Ensure the cache is empty before the test
      expect(Rails.cache.read(cache_key)).to be_nil

      # Perform the search and cache the results
      Rails.cache.fetch(cache_key) do
        Book.search(search_query)
      end

      # Check if the search result is cached
      not_cached_books = Book.search(search_query)
      expect(Rails.cache.read(cache_key)).to match_array(not_cached_books)
    end
  end
end

describe 'Movie' do
  before(:all) do
    Movie.clear_index!(true)
  end

  it 'returns array of single task hash on #ms_index!' do
    movie = Movie.create(title: 'Harry Potter')

    task = movie.ms_index!

    expect(task).to contain_exactly(a_hash_including('taskUid'))
  end

  it 'does not return any record with typo' do
    Movie.create(title: 'Harry Potter')

    expect(Movie.search('harry pottr', matching_strategy: 'all').size).to eq(0)
  end
end

describe 'Kaminari' do
  before(:all) do
    require 'kaminari'
    MeiliSearch::Rails.configuration[:pagination_backend] = :kaminari
    Restaurant.clear_index!(true)

    10.times do
      Restaurant.create(
        name: Faker::Restaurant.name,
        kind: Faker::Restaurant.type,
        description: Faker::Restaurant.description
      )
    end

    Restaurant.reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
  end

  after(:all) { MeiliSearch::Rails.configuration[:pagination_backend] = nil }

  it 'paginates' do
    hits = Restaurant.search ''
    expect(hits.total_count).to eq(Restaurant.raw_search('')['hits'].size)

    p1 = Restaurant.search '', page: 1, hits_per_page: 1
    expect(p1.size).to eq(1)
    expect(p1[0]).to eq(hits[0])
    expect(p1.total_count).to eq(Restaurant.raw_search('')['hits'].count)

    p2 = Restaurant.search '', page: 2, hits_per_page: 1
    expect(p2.size).to eq(1)
    expect(p2[0]).to eq(hits[1])
    expect(p2.total_count).to eq(Restaurant.raw_search('')['hits'].count)
  end

  it 'respects both camelCase and snake_case options' do
    expect(Restaurant.count).to be > 1

    # TODO: deprecate all camelcase attributes on v1.
    %i[hits_per_page hitsPerPage].each do |method|
      restaurants = Restaurant.search '', { page: 1, method => 1 }

      expect(restaurants.size).to eq(1)
    end
  end

  it 'does not return error if pagination params are strings' do
    p1 = Restaurant.search '', page: '1', hits_per_page: '1'
    expect(p1.size).to eq(1)
    expect(p1.total_count).to eq(Restaurant.raw_search('')['hits'].count)

    p2 = Restaurant.search '', page: '2', hits_per_page: '1'
    expect(p2.size).to eq(1)
    expect(p2.total_count).to eq(Restaurant.raw_search('')['hits'].count)
  end

  it 'returns records less than or equal to max_total_hits' do
    expect(Restaurant.search('*').size).to eq(5)
  end
end

describe 'Will_paginate' do
  before(:all) do
    require 'will_paginate'
    MeiliSearch::Rails.configuration[:pagination_backend] = :will_paginate
    Movie.clear_index!(true)

    10.times { Movie.create(title: Faker::Movie.title) }

    Movie.reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
  end

  after(:all) { MeiliSearch::Rails.configuration[:pagination_backend] = nil }

  it 'paginates' do
    hits = Movie.search '', hits_per_page: 2
    expect(hits.per_page).to eq(2)
    expect(hits.total_pages).to eq(3)
    expect(hits.total_entries).to eq(Movie.raw_search('')['hits'].count)
  end

  it 'returns most relevant elements in the first page' do
    hits = Movie.search '', hits_per_page: 2
    raw_hits = Movie.raw_search ''
    expect(hits[0]['id']).to eq(raw_hits['hits'][0]['id'].to_i)

    hits = Movie.search '', hits_per_page: 2, page: 2
    raw_hits = Movie.raw_search ''
    expect(hits[0]['id']).to eq(raw_hits['hits'][2]['id'].to_i)
  end

  it 'does not return error if pagination params are strings' do
    hits = Movie.search '', hits_per_page: '5'
    expect(hits.per_page).to eq(5)
    expect(hits.total_pages).to eq(1)
    expect(hits.current_page).to eq(1)

    hits = Movie.search '', hits_per_page: '5', page: '2'
    expect(hits.current_page).to eq(2)
  end

  it 'returns records less than or equal to max_total_hits' do
    expect(Movie.search('*').size).to eq(5)
  end
end

describe 'with pagination by pagy' do
  before(:all) do
    MeiliSearch::Rails.configuration[:pagination_backend] = :pagy
    MeiliSearch::Rails.configuration[:per_environment] = false
  end

  after(:all) do
    MeiliSearch::Rails.configuration[:pagination_backend] = nil
    MeiliSearch::Rails.configuration[:per_environment] = true
  end

  it 'has meaningful error when pagy is set as the pagination_backend' do
    Movie.create(title: 'Harry Potter').index!(true)

    logger = double

    allow(logger).to receive(:warn)
    allow(MeiliSearch::Rails).to receive(:logger).and_return(logger)

    Movie.search('')

    expect(logger).to have_received(:warn)
      .with('[meilisearch-rails] Remove `pagination_backend: :pagy` from your initializer, `pagy` it is not required for `pagy`')
  end
end

describe 'attributes_to_crop' do
  before(:all) do
    MeiliSearch::Rails.configuration[:per_environment] = false

    10.times do
      Restaurant.create(
        name: Faker::Restaurant.name,
        kind: Faker::Restaurant.type,
        description: Faker::Restaurant.description
      )
    end

    Restaurant.reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
  end

  after(:all) { MeiliSearch::Rails.configuration[:per_environment] = true }

  it 'includes _formatted object' do
    results = Restaurant.search('')
    raw_search_results = Restaurant.raw_search('')
    expect(results[0].formatted).not_to be_nil
    expect(results[0].formatted).to eq(raw_search_results['hits'].first['_formatted'])
    expect(results.first.formatted['description'].length).to be < results.first['description'].length
    expect(results.first.formatted['description']).to eq(raw_search_results['hits'].first['_formatted']['description'])
    expect(results.first.formatted['description']).not_to eq(results.first['description'])
  end
end

describe 'Disabled' do
  before(:all) do
    DisabledBoolean.index.delete_all_documents!
    DisabledProc.index.delete_all_documents!
    DisabledSymbol.index.delete_all_documents!
  end

  it 'disables the indexing using a boolean' do
    DisabledBoolean.create name: 'foo'
    expect(DisabledBoolean.search('').size).to eq(0)
  end

  it 'disables the indexing using a proc' do
    DisabledProc.create name: 'foo'
    expect(DisabledProc.search('').size).to eq(0)
  end

  it 'disables the indexing using a symbol' do
    DisabledSymbol.create name: 'foo'
    expect(DisabledSymbol.search('').size).to eq(0)
  end
end

unless OLD_RAILS
  describe 'EnqueuedDocument' do
    it 'enqueues a job' do
      expect do
        EnqueuedDocument.create! name: 'hellraiser'
      end.to raise_error('enqueued hellraiser')
    end

    it 'does not enqueue a job inside no index block' do
      expect do
        EnqueuedDocument.without_auto_index do
          EnqueuedDocument.create! name: 'test'
        end
      end.not_to raise_error
    end
  end

  describe 'DisabledEnqueuedDocument' do
    it '#ms_index! returns an empty array' do
      doc = DisabledEnqueuedDocument.create! name: 'test'

      expect(doc.ms_index!).to be_empty
    end

    it 'does not try to enqueue a job' do
      expect do
        DisabledEnqueuedDocument.create! name: 'test'
      end.not_to raise_error
    end
  end

  describe 'ConditionallyEnqueuedDocument' do
    before do
      allow(MeiliSearch::Rails::MSJob).to receive(:perform_later).and_return(nil)
      allow(MeiliSearch::Rails::MSCleanUpJob).to receive(:perform_later).and_return(nil)
    end

    it 'does not try to enqueue an index job when :if option resolves to false' do
      doc = ConditionallyEnqueuedDocument.create! name: 'test', is_public: false

      expect(MeiliSearch::Rails::MSJob).not_to have_received(:perform_later).with(doc, 'ms_index!')
    end

    it 'enqueues an index job when :if option resolves to true' do
      doc = ConditionallyEnqueuedDocument.create! name: 'test', is_public: true

      expect(MeiliSearch::Rails::MSJob).to have_received(:perform_later).with(doc, 'ms_index!')
    end

    it 'does enqueue a remove_from_index despite :if option' do
      doc = ConditionallyEnqueuedDocument.create!(name: 'test', is_public: true)
      expect(MeiliSearch::Rails::MSJob).to have_received(:perform_later).with(doc, 'ms_index!')

      doc.destroy!

      expect(MeiliSearch::Rails::MSCleanUpJob).to have_received(:perform_later).with(doc.ms_entries)
    end
  end
end

describe 'Misconfigured Block' do
  it 'forces the meilisearch block' do
    expect do
      MisconfiguredBlock.reindex!
    end.to raise_error(ArgumentError)
  end
end

describe 'People' do
  before do
    People.clear_index!(true)
    People.delete_all
  end

  before(:all) { MeiliSearch::Rails.configuration[:per_environment] = false }

  after(:all) { MeiliSearch::Rails.configuration[:per_environment] = true }

  it 'adds custom complex attribute' do
    People.create(first_name: 'Jane', last_name: 'Doe', card_number: 75_801_887)
    result = People.raw_search('Jane')
    expect(result['hits'][0]['full_name']).to eq('Jane Doe')
  end

  it 'has as uid the custom name specified' do
    People.create(first_name: 'Jane', last_name: 'Doe', card_number: 75_801_887)
    expect(People.index.uid).to eq(safe_index_uid('MyCustomPeople'))
  end

  it 'has the chosen field as custom primary key' do
    People.create(first_name: 'Jane', last_name: 'Doe', card_number: 75_801_887)
    index = MeiliSearch::Rails.client.fetch_index(safe_index_uid('MyCustomPeople'))
    expect(index.primary_key).to eq('card_number')
  end

  it 'does not call the API if there has been no attribute change' do
    People.create(first_name: 'Jane', last_name: 'Doe', card_number: 75_801_887)

    person = People.search('Jane').first

    expect do
      person.update(first_name: 'Jane')
    end.not_to change(People.index.tasks['results'], :size)
  end

  it 'does not auto-remove' do
    People.create(first_name: 'Joanna', last_name: 'Banana', card_number: 75_801_888)
    joanna = People.search('Joanna')[0]
    joanna.destroy
    result = People.raw_search('Joanna')
    expect(result['hits'].size).to eq(1)
  end

  it 'is able to remove manually' do
    bob = People.create(first_name: 'Bob', last_name: 'Sponge', card_number: 75_801_889)
    result = People.raw_search('Bob')
    expect(result['hits'].size).to eq(1)
    bob.remove_from_index!
    result = People.raw_search('Bob')
    expect(result['hits'].size).to eq(0)
  end

  it 'clears index manually' do
    People.create(first_name: 'Jane', last_name: 'Doe', card_number: 75_801_887)
    results = People.raw_search('')
    expect(results['hits'].size).not_to eq(0)
    People.clear_index!(true)
    results = People.raw_search('')
    expect(results['hits'].size).to eq(0)
  end
end

describe 'Animals' do
  it 'returns only the requested type' do
    Dog.create!([{ name: 'Toby the Dog' }, { name: 'Felix the Dog' }])
    Cat.create!([{ name: 'Toby the Cat' }, { name: 'Felix the Cat' }, { name: 'roar' }])

    expect(Dog.count).to eq(2)
    expect(Cat.count).to eq(3)

    expect(Cat.search('felix').size).to eq(1)
    expect(Cat.search('felix').first.name).to eq('Felix the Cat')
    expect(Dog.search('toby').size).to eq(1)
    expect(Dog.search('Toby').first.name).to eq('Toby the Dog')
  end

  it 'shares a single index' do
    cat_index = Cat.index.instance_variable_get('@index').uid
    dog_index = Dog.index.instance_variable_get('@index').uid

    expect(cat_index).to eq(dog_index)
  end

  describe '#ms_entries' do
    it 'returns the correct entry for each animal' do
      toby_dog = Dog.create!(name: 'Toby the Dog')
      taby_cat = Cat.create!(name: 'Taby the Cat')

      expect(toby_dog.ms_entries).to contain_exactly(
        a_hash_including('primary_key' => /dog_\d+/))

      expect(taby_cat.ms_entries).to contain_exactly(
        a_hash_including('primary_key' => /cat_\d+/))
    end
  end
end

describe 'Songs' do
  before(:all) { MeiliSearch::Rails.configuration[:per_environment] = false }

  after(:all) { MeiliSearch::Rails.configuration[:per_environment] = true }

  it 'targets multiple indices' do
    Song.create!(name: 'Coconut nut', artist: 'Smokey Mountain', premium: false, released: true) # Only song supposed to be added to Songs index
    Song.create!(name: 'Smoking hot', artist: 'Cigarettes before lunch', premium: true, released: true)
    Song.create!(name: 'Floor is lava', artist: 'Volcano', premium: true, released: false)
    Song.index.wait_for_task(Song.index.tasks['results'].first['uid'])
    MeiliSearch::Rails.client.index(safe_index_uid('PrivateSongs')).wait_for_task(MeiliSearch::Rails.client.index(safe_index_uid('PrivateSongs')).tasks['results'].first['uid'])
    results = Song.search('', index: safe_index_uid('Songs'))
    expect(results.size).to eq(1)
    raw_results = Song.raw_search('', index: safe_index_uid('Songs'))
    expect(raw_results['hits'].size).to eq(1)
    results = Song.search('', index: safe_index_uid('PrivateSongs'))
    expect(results.size).to eq(3)
    raw_results = Song.raw_search('', index: safe_index_uid('PrivateSongs'))
    expect(raw_results['hits'].size).to eq(3)
  end
end

describe 'Raise on failure' do
  before { Vegetable.instance_variable_set('@ms_indexes', nil) }

  it 'raises on failure' do
    expect do
      Fruit.search('', { filter: 'title = Nightshift' })
    end.to raise_error(MeiliSearch::ApiError)
  end

  it 'does not raise on failure' do
    expect do
      Vegetable.search('', { filter: 'title = Kale' })
    end.not_to raise_error
  end

  context 'when Meilisearch server take too long to answer' do
    let(:index_instance) { instance_double(MeiliSearch::Index, settings: nil, update_settings: nil) }
    let(:slow_client) { instance_double(MeiliSearch::Client, index: index_instance) }

    before do
      allow(slow_client).to receive(:create_index)
      allow(MeiliSearch::Rails).to receive(:client).and_return(slow_client)
    end

    it 'does not raise error timeouts on reindex' do
      allow(index_instance).to receive(:add_documents).and_raise(MeiliSearch::TimeoutError)

      expect do
        Vegetable.create(name: 'potato')
      end.not_to raise_error
    end

    it 'does not raise error timeouts on data addition' do
      allow(index_instance).to receive(:add_documents).and_return(nil)

      expect do
        Vegetable.ms_reindex!
      end.not_to raise_error
    end
  end
end

context 'when a searchable attribute is not an attribute' do
  let(:other_people_class) do
    Class.new(People) do
      def self.name
        'People'
      end
    end
  end

  let(:logger) { instance_double('Logger', warn: nil) }

  before do
    allow(MeiliSearch::Rails).to receive(:logger).and_return(logger)

    other_people_class.meilisearch index_uid: safe_index_uid('Others'), primary_key: :card_number do
      attribute :first_name
      searchable_attributes %i[first_name last_name]
    end
  end

  it 'warns the user' do
    expect(logger).to have_received(:warn).with(/meilisearch-rails.+last_name/)
  end
end

context "when have a internal class defined in the app's scope" do
  it 'does not raise NoMethodError' do
    Task.create(title: 'my task #1')

    expect do
      Task.search('task')
    end.not_to raise_error
  end
end

context 'when MeiliSearch calls are deactivated' do
  it 'is active by default' do
    expect(MeiliSearch::Rails).to be_active
  end

  describe '#deactivate!' do
    context 'without block' do
      before { MeiliSearch::Rails.deactivate! }

      after { MeiliSearch::Rails.activate! }

      it 'deactivates the requests and keep the state' do
        expect(MeiliSearch::Rails).not_to be_active
      end

      it 'responds with a black hole' do
        expect(MeiliSearch::Rails.client.foo.bar.now.nil.item.issue).to be_nil
      end

      it 'deactivates requests' do
        expect do
          Task.create(title: 'my task #1')
          Task.search('task')
        end.not_to raise_error
      end
    end

    context 'with a block' do
      it 'disables only around call' do
        MeiliSearch::Rails.deactivate! do
          expect(MeiliSearch::Rails).not_to be_active
        end

        expect(MeiliSearch::Rails).to be_active
      end

      it 'works even when the instance made calls earlier' do
        Task.destroy_all
        Task.create!(title: 'deactivated #1')

        MeiliSearch::Rails.deactivate! do
          # always 0 since the black hole will return the default values
          expect(Task.search('deactivated').size).to eq(0)
        end

        expect(MeiliSearch::Rails).to be_active
        expect(Task.search('#1').size).to eq(1)
      end

      it 'works in multi-threaded environments' do
        Threads.new(5, log: $stdout).assert(20) do |_i, _r|
          MeiliSearch::Rails.deactivate! do
            expect(MeiliSearch::Rails).not_to be_active
          end

          expect(MeiliSearch::Rails).to be_active
        end
      end
    end
  end
end
