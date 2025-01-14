require 'spec_helper'

RSpec.describe 'Meilisearch::Rails::MSJob' do
  include ActiveJob::TestHelper

  subject(:job) { Meilisearch::Rails::MSJob }

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
end
