require 'support/async_helper'
require 'support/models/song'

describe AsyncHelper do
  describe '.await_meilisearch_tasks' do
    let(:private_songs_index) { safe_index_uid('PrivateSongs') }
    let(:public_songs_index) { safe_index_uid('Songs') }

    it 'waits for all pending tasks on the provided indexes' do
      Song.clear_index!(true)

      songs = AsyncHelper.await_meilisearch_tasks(index_uids: [private_songs_index, public_songs_index]) do
        [
          Song.create!(name: 'Coconut nut', artist: 'Smokey Mountain', premium: false, released: true),
          Song.create!(name: 'Smoking hot', artist: 'Cigarettes before lunch', premium: true, released: true),
          Song.create!(name: 'Floor is lava', artist: 'Volcano', premium: true, released: false)
        ]
      end

      expect(Song.search('', index: public_songs_index)).to contain_exactly(songs.first)
      expect(Song.search('', index: private_songs_index)).to match(songs)
    end
  end
end
