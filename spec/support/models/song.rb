require 'support/active_record_schema'

ar_schema.create_table :songs do |t|
  t.string :name
  t.string :artist
  t.boolean :released
  t.boolean :premium
end

class Song < ActiveRecord::Base
  include Meilisearch::Rails

  PUBLIC_INDEX_UID  = safe_index_uid('Songs')
  SECURED_INDEX_UID = safe_index_uid('PrivateSongs')

  meilisearch index_uid: SECURED_INDEX_UID do
    searchable_attributes %i[name artist]

    add_index PUBLIC_INDEX_UID, if: :public? do
      searchable_attributes %i[name artist]
    end

    proximity_precision 'byAttribute'
  end

  private

  def public?
    released && !premium
  end
end
