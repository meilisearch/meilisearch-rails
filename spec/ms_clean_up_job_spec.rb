require 'spec_helper'

RSpec.describe 'MeiliSearch::Rails::MSCleanUpJob' do
  include ActiveJob::TestHelper

  subject(:job) { MeiliSearch::Rails::MSCleanUpJob }

  subject(:record) do
    Book.create name: "Moby Dick", author: "Herman Mellville",
                premium: false, released: true
  end

  let(:record_entries) do
    record.ms_entries(true).each { |h| h[:index_uid] += '_test' }
  end

  let(:indexes) do
    %w[SecuredBook BookAuthor Book].map do |uid|
      Book.index(safe_index_uid uid)
    end
  end

  it 'removes record from all indexes' do
    indexes.each(&:delete_all_documents)

    record

    indexes.each do |index|
      index.wait_for_task(index.tasks['results'].first['uid'])
      expect(index.search('*')['hits']).to be_one
    end

    job.perform_now(record_entries)

    indexes.each do |index|
      expect(index.search('*')['hits']).to be_empty
    end
  end

  context 'when record is already destroyed' do
    subject(:record) do
      Restaurant.create(
        name: "Los Pollos Hermanos",
        kind: "Mexican",
        description: "Mexican chicken restaurant in Albuquerque, New Mexico.")
    end

    it 'successfully deletes its document in the index' do
      record
      Restaurant.index.wait_for_task(Restaurant.index.tasks['results'].first['uid'])
      expect(Restaurant.index.search("Pollos")['hits']).to be_one

      record.delete # does not run callbacks, unlike #destroy

      job.perform_later(record_entries)
      expect { perform_enqueued_jobs }.not_to raise_error

      expect(Restaurant.index.search("Pollos")['hits']).to be_empty
    end
  end
end
