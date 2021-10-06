require File.expand_path(File.join(__dir__, "spec_helper"))

describe MeiliSearch::Configuration do
  let(:configuration) {
    {
      meilisearch_host: "http://localhost:7700",
      meilisearch_api_key: "s3cr3tap1k3y",
    }
  }

  describe ".client" do
    let(:client_double) { double MeiliSearch::Client }

    before do
      allow(MeiliSearch).to receive(:configuration) { configuration }
      allow(MeiliSearch::Client).to receive(:new) { client_double }
    end

    it "initializes a MeiliSearch::Client" do
      expect(MeiliSearch.client).to eq(client_double)

      expect(MeiliSearch::Client)
        .to have_received(:new)
        .with("http://localhost:7700", "s3cr3tap1k3y", {})
    end

    context 'without meilisearch_host' do
      let(:configuration) {
        {
          meilisearch_host: nil,
          meilisearch_api_key: "s3cr3tap1k3y",
        }
      }

      it 'defines a default value for meilisearch_host' do
        expect(MeiliSearch.client).to eq(client_double)

        expect(MeiliSearch::Client)
          .to have_received(:new)
          .with("http://localhost:7700", "s3cr3tap1k3y", {})
      end
    end

    context "with timeout and max retries" do
      let(:configuration) {
        {
          meilisearch_host: "http://localhost:7700",
          meilisearch_api_key: "s3cr3tap1k3y",
          timeout: 2,
          max_retries: 1,
        }
      }

      it "forwards them to the client" do
        expect(MeiliSearch.client).to eq(client_double)

        expect(MeiliSearch::Client)
          .to have_received(:new)
          .with(
            "http://localhost:7700",
            "s3cr3tap1k3y",
            timeout: 2,
            max_retries: 1,
          )
      end
    end
  end

  context 'when use MeiliSearch without configuration' do
    around do |example|
      config = MeiliSearch.configuration
      MeiliSearch.configuration = nil

      example.run

      MeiliSearch.configuration = config
    end

    it 'raise NotConfigured error' do
      expect {
        MeiliSearch.configuration
      }.to raise_error(MeiliSearch::NotConfigured, /Please configure MeiliSearch/)
    end
  end
end
