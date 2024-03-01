require 'spec_helper'
require 'support/models/book'
require 'support/models/color'

describe MeiliSearch::Rails::Configuration do
  before { stub_const('MeiliSearch::Rails::VERSION', '0.0.1') }

  let(:configuration) do
    {
      meilisearch_url: 'http://localhost:7700',
      meilisearch_api_key: 's3cr3tap1k3y'
    }
  end

  describe '.client' do
    let(:client_double) { double MeiliSearch::Client }

    before do
      allow(MeiliSearch::Rails).to receive(:configuration) { configuration }
      allow(MeiliSearch::Client).to receive(:new) { client_double }
    end

    it 'initializes a MeiliSearch::Client' do
      expect(MeiliSearch::Rails.client).to eq(client_double)

      expect(MeiliSearch::Client)
        .to have_received(:new)
        .with('http://localhost:7700', 's3cr3tap1k3y', client_agents: 'Meilisearch Rails (v0.0.1)')
    end

    context 'without meilisearch_url' do
      let(:configuration) do
        {
          meilisearch_url: nil,
          meilisearch_api_key: 's3cr3tap1k3y'
        }
      end

      it 'defines a default value for meilisearch_url' do
        expect(MeiliSearch::Rails.client).to eq(client_double)

        expect(MeiliSearch::Client)
          .to have_received(:new)
          .with('http://localhost:7700', 's3cr3tap1k3y', { client_agents: 'Meilisearch Rails (v0.0.1)' })
      end
    end

    context 'with timeout and max retries' do
      let(:configuration) do
        {
          meilisearch_url: 'http://localhost:7700',
          meilisearch_api_key: 's3cr3tap1k3y',
          timeout: 2,
          max_retries: 1
        }
      end

      it 'forwards them to the client' do
        expect(MeiliSearch::Rails.client).to eq(client_double)

        expect(MeiliSearch::Client)
          .to have_received(:new)
          .with('http://localhost:7700', 's3cr3tap1k3y', client_agents: 'Meilisearch Rails (v0.0.1)', timeout: 2, max_retries: 1)
      end
    end
  end

  context 'with per_environment' do
    # per_environment is already enabled in testing
    # no setup is required

    it 'adds a Rails env-based index suffix' do
      expect(Color.index_uid).to eq(safe_index_uid('Color') + "_#{Rails.env}")
    end

    it 'uses suffix in the additional index as well' do
      index = Book.index(safe_index_uid('Book'))
      expect(index.uid).to eq("#{safe_index_uid('Book')}_#{Rails.env}")
    end
  end

  context 'when use Meilisearch without configuration' do
    around do |example|
      config = MeiliSearch::Rails.configuration
      MeiliSearch::Rails.configuration = nil

      example.run

      MeiliSearch::Rails.configuration = config
    end

    it 'raise NotConfigured error' do
      expect do
        MeiliSearch::Rails.configuration
      end.to raise_error(MeiliSearch::Rails::NotConfigured, /Please configure Meilisearch/)
    end
  end
end
