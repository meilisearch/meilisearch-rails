require 'spec_helper'

describe MeiliSearch::Rails::Utilities do
  around do |example|
    included_in = MeiliSearch::Rails.instance_variable_get :@included_in
    MeiliSearch::Rails.instance_variable_set :@included_in, []

    example.run

    MeiliSearch::Rails.instance_variable_set :@included_in, included_in
  end

  it 'gets the models where Meilisearch module was included' do
    expect(described_class.get_model_classes - [Dummy, DummyChild, DummyGrandChild]).to be_empty
  end
end
