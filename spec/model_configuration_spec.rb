require 'spec_helper'
require 'support/models/unconfigured_model'

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
end
