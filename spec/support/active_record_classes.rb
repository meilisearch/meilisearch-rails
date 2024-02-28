require 'support/active_record_schema'
Dir["#{File.dirname(__FILE__)}/models/*.rb"].sort.each { |file| require file }

ar_schema.instance_exec do
  create_table :uniq_users, id: false do |t|
    t.string :name
  end
  create_table :nullable_ids
  create_table :mongo_documents do |t|
    t.string :name
  end
  create_table :ebooks do |t|
    t.string :name
    t.string :author
    t.boolean :premium
    t.boolean :released
  end
  create_table :encoded_strings
end

class UniqUser < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('UniqUser'), primary_key: :name
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

class Ebook < ActiveRecord::Base
  include MeiliSearch::Rails
  attr_accessor :current_time, :published_at

  meilisearch synchronous: true, index_uid: safe_index_uid('eBooks') do
    searchable_attributes [:name]
  end

  def ms_dirty?
    return true if published_at.nil? || current_time.nil?

    # Consider dirty if published date is in the past
    # This doesn't make so much business sense but it's easy to test.
    published_at < current_time
  end
end

class EncodedString < ActiveRecord::Base
  include MeiliSearch::Rails

  meilisearch synchronous: true, force_utf8_encoding: true, index_uid: safe_index_uid('EncodedString') do
    attribute :value do
      "\xC2\xA0\xE2\x80\xA2\xC2\xA0".force_encoding('ascii-8bit')
    end
  end
end
