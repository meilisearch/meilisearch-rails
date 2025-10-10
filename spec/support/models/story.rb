require 'support/active_record_schema'

ar_schema.create_table :stories do |t|
  t.integer :story_id
  t.string :title
end

class Story < ActiveRecord::Base
  include MeiliSearch::Rails

  self.primary_key = 'story_id' # Use model primary_key for index primary key

  meilisearch index_uid: safe_index_uid('MyCustomStory') # Don't set primary_key in meilisearch
end

module TestUtil
  def self.reset_stories!
    Story.clear_index!
    Story.delete_all
  end
end
