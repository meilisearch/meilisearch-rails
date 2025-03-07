require 'support/active_record_schema'

ar_schema.create_table :disabled_booleans do |t|
  t.string :name
end

ar_schema.create_table :disabled_procs do |t|
  t.string :name
end

ar_schema.create_table :disabled_symbols do |t|
  t.string :name
end

class DisabledBoolean < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch synchronous: true, disable_indexing: true, index_uid: safe_index_uid('DisabledBoolean')
end

class DisabledProc < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch synchronous: true, disable_indexing: proc { true }, index_uid: safe_index_uid('DisabledProc')
end

class DisabledSymbol < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch synchronous: true, disable_indexing: :truth, index_uid: safe_index_uid('DisabledSymbol')

  def self.truth
    true
  end
end
