require 'spec_helper'

RSpec.describe 'MeiliSearch::Rails::MSJob' do
  include ActiveJob::TestHelper

  subject(:job) { MeiliSearch::Rails::MSJob }

  let(:record) { double }
  let(:method_name) { :index! }

  it 'invokes public methods on the record' do
    allow(record).to receive(method_name).and_return(nil)

    job.perform_now(record, method_name)

    expect(record).to have_received(method_name)
  end

  it 'uses :meilisearch as the default queue' do
    expect(job.queue_name).to eq('meilisearch')
  end

  context 'if record is already destroyed' do
    fit 'successfully deletes its document in the index' do
      pollos = Restaurant.create(
        name: "Los Pollos Hermanos",
        kind: "Mexican",
        description: "Mexican chicken restaurant in Albuquerque, New Mexico."
      )

      Restaurant.index.wait_for_task(Restaurant.index.tasks['results'].first['uid'])
      expect(Restaurant.index.search("Pollos")['hits']).to be_one

      pollos.delete # does not run callbacks, unlike #destroy

      job.perform_later(pollos, :ms_remove_from_index!)
      expect { perform_enqueued_jobs }.not_to raise_error

      expect(Restaurant.index.search("Pollos")['hits']).to be_empty
    end
  end
end
