require File.expand_path(File.join(__dir__, "spec_helper"))

MeiliSearch.configuration = {
  meilisearch_host: ENV['MEILISEARCH_HOST'],
  meilisearch_api_key: ENV['MEILISEARCH_API_KEY'],
}

describe MeiliSearch::Configuration do
  let(:configuration) {
    {
      meilisearch_host: "http://localhost:7700",
      meilisearch_api_key: "s3cr3tap1k3y",
    }
  }

  before do
    allow(MeiliSearch).to receive(:configuration) { configuration }
  end

  describe ".client" do
    let(:client_double) { double MeiliSearch::Client }

    before do
      allow(MeiliSearch::Client).to receive(:new) { client_double }
    end

    it "initializes a MeiliSearch::Client" do
      expect(MeiliSearch.client).to eq(client_double)

      expect(MeiliSearch::Client)
        .to have_received(:new)
        .with("http://localhost:7700", "s3cr3tap1k3y", {})
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
end
