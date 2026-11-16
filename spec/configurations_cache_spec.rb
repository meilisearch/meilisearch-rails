describe 'Configuration cache' do
  let(:index_uids) do
    {
      primary: safe_index_uid('ConfigCachePrimary'),
      additional: safe_index_uid('ConfigCacheAdditional'),
      nested: safe_index_uid('ConfigCacheNested')
    }
  end

  # A fresh class per example, so the cached configurations never leak between examples.
  let(:model) do
    uids = index_uids

    klass = Class.new do
      include Meilisearch::Rails

      def self.model_name
        'ConfigCacheModel'
      end
    end
    stub_const('ConfigCacheModel', klass)

    klass.meilisearch index_uid: uids[:primary] do
      searchable_attributes [:name]

      add_index uids[:additional] do
        searchable_attributes [:author]

        add_index uids[:nested] do
          searchable_attributes [:genre]
        end
      end
    end

    klass
  end

  # Keyed by the uid each index resolves to, which includes the environment suffix in this suite.
  let(:own_settings) do
    {
      index_uids[:primary] => { searchable_attributes: [:name] },
      index_uids[:additional] => { searchable_attributes: [:author] },
      index_uids[:nested] => { searchable_attributes: [:genre] }
    }.transform_keys { |index_uid| model.ms_index_uid(index_uid: index_uid) }
  end

  let(:sent_settings) { {} }

  before do
    allow(Meilisearch::Rails::SafeIndex).to receive(:new) do |index_uid, *|
      instance_double(Meilisearch::Rails::SafeIndex).tap do |index|
        allow(index).to receive(:update_settings) do |settings|
          sent_settings[index_uid] = settings
          { 'taskUid' => 0 }
        end
      end
    end
  end

  # Including the module registers the class globally, and that outlives the stubbed constant.
  after { Meilisearch::Rails.included_in.delete(model) }

  it 'neither reads nor overwrites the configurations another gem caches in @configurations' do
    # algoliasearch-rails stores a hash of index options => settings object in this ivar.
    foreign_settings = Struct.new(:to_settings).new({ ranking: ['typo'], indexLanguages: ['ja'] })
    foreign_configurations = { { index_name: 'foreign_index' } => foreign_settings }
    model.instance_variable_set(:@configurations, foreign_configurations.dup)

    model.ms_set_settings

    expect(sent_settings).to eq(own_settings)
    expect(model.instance_variable_get(:@configurations)).to eq(foreign_configurations)
  end
end
