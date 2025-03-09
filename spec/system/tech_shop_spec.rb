require 'support/async_helper'
require 'support/models/product'

describe 'Tech shop' do
  before(:all) do
    Product.delete_all
    Product.index.delete_all_documents!

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

    Product.reindex!(Meilisearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
  end

  context 'product' do
    it 'defaults to asynchronous' do
      p = Product.new

      expect(p).not_to be_ms_synchronous
    end

    it 'supports manual indexing' do
      products_before_clear = Product.raw_search('')['hits']
      expect(products_before_clear).not_to be_empty

      Product.clear_index!(true)

      products_after_clear = Product.raw_search('')['hits']
      expect(products_after_clear).to be_empty
      Product.reindex!(Meilisearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)

      products_after_reindex = Product.raw_search('')['hits']
      expect(products_after_reindex).not_to be_empty
      expect(products_before_clear).to eq(products_after_reindex)
    end
  end

  describe 'basic searching' do
    it 'finds the iphone' do
      results = Product.search('iphone')
      expect(results).to contain_exactly(@iphone)
    end

    it 'searches case insensitively' do
      results = Product.search('IPHONE')
      expect(results).to contain_exactly(@iphone)
    end

    it 'finds all amazon products' do
      results = Product.search('amazon')
      expect(results).to contain_exactly(@android, @samsung, @motorola)
    end

    it 'finds all "palm" phones with wildcard word search' do
      results = Product.search('pal')
      expect(results).to contain_exactly(@palmpre, @palm_pixi_plus)
    end

    it 'searches multiple words from the same field' do
      results = Product.search('palm pixi plus')
      expect(results).to contain_exactly(@palm_pixi_plus)
    end

    it 'finds using phrase search' do
      results = Product.search('coco "palm"')
      expect(results).to contain_exactly(@palm_pixi_plus)
    end

    it 'narrows the results by searching across multiple fields' do
      results = Product.search('apple iphone')
      expect(results).to include(@iphone, @macbook)
    end

    it 'does not search on non-indexed fields' do
      expect(Product.search('features')).to be_empty
    end

    it 'deletes associated document on #destroy' do
      ipad = Product.create!(name: 'ipad', href: 'apple', tags: ['awesome', 'great battery'],
                             description: 'Big screen')

      ipad.index!(true)
      results = Product.search('ipad')
      expect(results).to contain_exactly(ipad)

      ipad.destroy
      AsyncHelper.await_last_task

      results = Product.raw_search('ipad')['hits']
      expect(results).to be_empty
    end

    context 'when a document cannot be found in ActiveRecord' do
      it 'does not throw an exception' do
        Product.index.add_documents(@palmpre.attributes.merge(id: -1)).await
        expect { Product.search('pal') }.not_to raise_error
        Product.index.delete_document(-1).await
      end

      it 'returns other available results' do
        Product.index.add_documents(@palmpre.attributes.merge(id: -1)).await
        expect(Product.search('pal').size).to eq(2)
        Product.index.delete_document(-1).await
      end
    end

    it 'reindexing does not duplicate record' do
      expect(Product.search('nokia')).to contain_exactly(@nokia)
      @nokia.index!
      expect(Product.search('nokia')).to contain_exactly(@nokia)
      @nokia.index!
      @nokia.index!
      expect(Product.search('nokia')).to contain_exactly(@nokia)
    end

    it 'does not return products that are not indexable' do
      @sekrit.index!
      @no_href.index!
      results = Product.search('sekrit')
      expect(results).to be_empty
    end

    it 'includes instances of subclasses' do
      @camera.index!
      results = Product.search('eos rebel')
      expect(results).to contain_exactly(@camera)
    end

    it 'deletes a document that is no longer indexable' do
      results = Product.search('sekrit')
      expect(results).to be_empty

      @sekrit.update(release_date: Time.now - 1.day)
      @sekrit.index!(true)
      results = Product.search('sekrit')
      expect(results).to contain_exactly(@sekrit)

      @sekrit.update(release_date: Time.now + 1.day)
      @sekrit.save!
      @sekrit.index!(true)
      results = Product.search('sekrit')
      expect(results).to be_empty
    end

    it 'supports synonyms' do
      expect(Product.search('pomme')).to eq(Product.search('apple'))
      expect(Product.search('m_b_p')).to eq(Product.search('macbookpro'))
    end
  end
end
