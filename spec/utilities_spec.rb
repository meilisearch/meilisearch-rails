require 'spec_helper'
require 'rake'

describe Meilisearch::Rails::Utilities do
  around do |example|
    included_in = Meilisearch::Rails.instance_variable_get :@included_in
    Meilisearch::Rails.instance_variable_set :@included_in, []

    example.run

    Meilisearch::Rails.instance_variable_set :@included_in, included_in
  end

  it 'gets the models where Meilisearch module was included' do
    expect(described_class.get_model_classes - [Dummy, DummyChild, DummyGrandChild]).to be_empty
  end

  context 'when invoked from rake task' do
    before do
      file = File.join('..', 'lib', 'meilisearch', 'rails', 'tasks', 'meilisearch')
      Rake.application.rake_require file.to_s
      Rake::Task.define_task(:environment)
    end

    {
      reindex: :reindex_all_models,
      set_all_settings: :set_settings_all_models,
      clear_indexes: :clear_all_indexes
    }.each do |task, method_name|
      it "calls #{described_class}.#{method_name} successfully" do
        allow(described_class).to receive(method_name).and_return(nil)

        Rake.application.invoke_task "meilisearch:#{task}"

        expect(described_class).to have_received(method_name)
      end
    end
  end
end
