require 'spec_helper'

RSpec.describe 'Meilisearch::Rails::MSCleanUpJob' do
  include ActiveJob::TestHelper

  def clean_up_indexes
    indexes.each(&:delete_all_documents)
  end

  def create_indexed_record
    record

    indexes.each do |index|
      index.wait_for_task(index.tasks['results'].last['uid'])
    end
  end

  subject(:clean_up) { Meilisearch::Rails::MSCleanUpJob }

  let(:record) do
    Book.create name: "Moby Dick", author: "Herman Mellville",
                premium: false, released: true
  end

  let(:record_entries) do
    record.ms_entries(true)
  end

  let(:indexes) do
    %w[SecuredBook BookAuthor Book].map do |uid|
      Book.index(safe_index_uid uid)
    end
  end

  it 'removes record from all indexes' do
    clean_up_indexes

    create_indexed_record

    clean_up.perform_now(record_entries)

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

    let(:indexes) { [Restaurant.index] }

    it 'successfully deletes its document in the index' do
      clean_up_indexes

      create_indexed_record

      record.delete # does not run callbacks, unlike #destroy

      clean_up.perform_later(record_entries)
      expect { perform_enqueued_jobs }.not_to raise_error

      indexes.each do |index|
        expect(index.search('*')['hits']).to be_empty
      end
    end
  end
end
