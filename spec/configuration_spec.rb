require 'spec_helper'

describe MeiliSearch::Rails::Configuration do
  let(:configuration) do
    {
      meilisearch_host: 'http://localhost:7700',
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
        .with('http://localhost:7700', 's3cr3tap1k3y', client_agents: 'Meilisearch Rails (v0.7.0)')
    end

    context 'without meilisearch_host' do
      let(:configuration) do
        {
          meilisearch_host: nil,
          meilisearch_api_key: 's3cr3tap1k3y'
        }
      end

      it 'defines a default value for meilisearch_host' do
        expect(MeiliSearch::Rails.client).to eq(client_double)

        expect(MeiliSearch::Client)
          .to have_received(:new)
          .with('http://localhost:7700', 's3cr3tap1k3y', { client_agents: 'Meilisearch Rails (v0.7.0)' })
      end
    end

    context 'with timeout and max retries' do
      let(:configuration) do
        {
          meilisearch_host: 'http://localhost:7700',
          meilisearch_api_key: 's3cr3tap1k3y',
          timeout: 2,
          max_retries: 1
        }
      end

      it 'forwards them to the client' do
        expect(MeiliSearch::Rails.client).to eq(client_double)

        expect(MeiliSearch::Client)
          .to have_received(:new)
          .with('http://localhost:7700', 's3cr3tap1k3y', client_agents: 'Meilisearch Rails (v0.7.0)', timeout: 2, max_retries: 1)
      end
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
