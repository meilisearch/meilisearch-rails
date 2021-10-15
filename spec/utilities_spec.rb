require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

MeiliSearch.configuration = { meilisearch_host: ENV['MEILISEARCH_HOST'], meilisearch_api_key: ENV['MEILISEARCH_API_KEY'] }

describe MeiliSearch::Utilities do

  around(:each) do |example|
    included_in = MeiliSearch.instance_variable_get :@included_in
    MeiliSearch.instance_variable_set :@included_in, []

    example.run

    MeiliSearch.instance_variable_set :@included_in, included_in
  end

  before(:each) do
    class Dummy
      include MeiliSearch

      def self.model_name
        "Dummy"
      end

      meilisearch
    end

    class DummyChild < Dummy
    end

    class DummyGrandChild < DummyChild
    end
  end

  it "gets the models where MeiliSearch module was included" do
    (MeiliSearch::Utilities.get_model_classes - [Dummy, DummyChild, DummyGrandChild]).should == []
  end

end
