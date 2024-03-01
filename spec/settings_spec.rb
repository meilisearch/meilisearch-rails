require 'spec_helper'
require 'support/models/book'
require 'support/models/people'

describe MeiliSearch::Rails::IndexSettings do
  describe 'add_attribute' do
    context 'with a symbol' do
      it 'calls method for new attribute' do
        TestUtil.reset_people!

        People.create(first_name: 'Jane', last_name: 'Doe', card_number: 75_801_887)

        result = People.raw_search('Jane')
        expect(result['hits'][0]['full_name']).to eq('Jane Doe')
      end
    end
  end

  describe 'faceting' do
    it 'respects max values per facet' do
      TestUtil.reset_books!

      4.times do
        Book.create! name: Faker::Book.title, author: Faker::Book.author,
                     genre: Faker::Book.unique.genre
      end

      genres = Book.distinct.pluck(:genre)

      results = Book.search('', { facets: ['genre'] })

      expect(genres.size).to be > 3
      expect(results.facets_distribution['genre'].size).to eq(3)
    end
  end

  describe 'typo_tolerance' do
    it 'searches with one typo min size' do
      TestUtil.reset_books!

      Book.create! name: 'The Lord of the Rings', author: 'me', premium: false, released: true
      results = Book.search('Lrod')
      expect(results).to be_empty

      results = Book.search('Rnigs')
      expect(results).to be_one
    end

    it 'searches with two typo min size' do
      TestUtil.reset_books!

      Book.create! name: 'Dracula', author: 'me', premium: false, released: true
      results = Book.search('Darclua')
      expect(results).to be_empty

      Book.create! name: 'Frankenstein', author: 'me', premium: false, released: true
      results = Book.search('Farnkenstien')
      expect(results).to be_one
    end
  end

  describe 'settings change detection' do
    let(:record) { Color.create name: 'dark-blue', short_name: 'blue' }

    context 'without changing settings' do
      it 'does not call update settings' do
        allow(Color.index).to receive(:update_settings).and_call_original

        record.ms_index!

        expect(Color.index).not_to have_received(:update_settings)
      end
    end

    context 'when settings have been changed' do
      it 'makes a request to update settings' do
        idx = Color.index
        task = idx.update_settings(
          filterable_attributes: ['none']
        )
        idx.wait_for_task task['taskUid']

        allow(idx).to receive(:update_settings).and_call_original

        record.ms_index!

        expect(Color.index).to have_received(:update_settings).once
      end
    end
  end
end
