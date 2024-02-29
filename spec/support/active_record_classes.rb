require 'support/active_record_schema'
Dir["#{File.dirname(__FILE__)}/models/*.rb"].sort.each { |file| require file }

ar_schema.instance_exec do
  create_table :nullable_ids
  create_table :mongo_documents do |t|
    t.string :name
  end
end

class NullableId < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('NullableId'), primary_key: :custom_id,
              if: :never

  def custom_id
    nil
  end

  def never
    false
  end
end

class MongoDocument < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch index_uid: safe_index_uid('MongoDocument')

  def self.reindex!
    raise NameError, 'never reached'
  end

  def index!
    raise NameError, 'never reached'
  end
end

