require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

MeiliSearch.configuration = { :application_id => ENV['MEILISEARCH_HOST'], :api_key => ENV['MEILISEARCH_API_KEY'] }

describe MeiliSearch::Utilities do

  before(:each) do
    @included_in = MeiliSearch.instance_variable_get :@included_in
    MeiliSearch.instance_variable_set :@included_in, []

    class Dummy
      include MeiliSearch

      def self.model_name
        "Dummy"
      end

      meilisearch
    end
  end

  after(:each) do
    MeiliSearch.instance_variable_set :@included_in, @included_in
  end

  it "should get the models where MeiliSearch module was included" do
    (MeiliSearch::Utilities.get_model_classes - [Dummy]).should == []
  end

end
