require 'spec_helper'
require 'support/models/unconfigured_model'
require 'support/sequel_models/book'
require 'support/models/color'

describe 'Model configuration' do
  describe 'options' do
    context 'if passed :per_environment' do
      it 'throws error' do
        expect do
          UnconfiguredModel.meilisearch per_environment: true
        end.to raise_error(MeiliSearch::Rails::BadConfiguration)
      end
    end

    context 'if passed :enqueue and :synchronous' do
      it 'complains about incompatible options' do
        expect do
          UnconfiguredModel.meilisearch enqueue: true, synchronous: true
        end.to raise_error(ArgumentError)
      end
    end
  end

  describe '#sequel_model?' do
    it 'returns false for activerecord' do
      expect(Color.ms_config).not_to be_sequel_model
    end

    it 'returns true for sequel' do
      expect(SequelBook.ms_config).to be_sequel_model
    end

    # TODO: Add similar methods for mongodb
  end

  describe '#active_record_model?' do
    it 'returns true for activerecord' do
      expect(Color.ms_config).to be_active_record_model
    end

    it 'returns false for sequel' do
      expect(SequelBook.ms_config).not_to be_active_record_model
    end
  end
end
