require 'support/models/product'

describe 'Tech shop' do
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
