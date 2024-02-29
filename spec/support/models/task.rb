require 'support/active_record_schema'

ar_schema.create_table :tasks do |t|
  t.string :title
end

class Task < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('Task')
end
