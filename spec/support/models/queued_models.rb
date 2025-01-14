require 'support/active_record_schema'

ar_schema.create_table :enqueued_documents do |t|
  t.string :name
end

ar_schema.create_table :disabled_enqueued_documents do |t|
  t.string :name
end

ar_schema.create_table :conditionally_enqueued_documents do |t|
  t.string :name
  t.boolean :is_public
end

class EnqueuedDocument < ActiveRecord::Base
  include Meilisearch::Rails

  include GlobalID::Identification

  def id
    read_attribute(:id)
  end

  def self.find(_id)
    EnqueuedDocument.first
  end

  meilisearch enqueue: proc { |record| raise "enqueued #{record.name}" },
              index_uid: safe_index_uid('EnqueuedDocument') do
    attributes [:name]
  end
end

class DisabledEnqueuedDocument < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch(enqueue: proc { |_record| raise 'enqueued' },
              index_uid: safe_index_uid('EnqueuedDocument'),
              disable_indexing: true) do
    attributes [:name]
  end
end

class ConditionallyEnqueuedDocument < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch(enqueue: true,
              index_uid: safe_index_uid('ConditionallyEnqueuedDocument'),
              if: :should_index?) do
    attributes %i[name is_public]
  end

  def should_index?
    is_public
  end
end
