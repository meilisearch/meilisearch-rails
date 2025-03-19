require 'support/active_record_schema'

ar_schema.create_table :namespaced_models do |t|
  t.string :name
  t.integer :another_private_value
end

ar_schema.create_table :nested_items do |t|
  t.integer :parent_id
  t.boolean :hidden
end

ar_schema.create_table :misconfigured_blocks do |t|
  t.string :name
end

ar_schema.create_table :serialized_documents do |t|
  t.string :name
  t.string :skip
end

ar_schema.create_table :encoded_strings

module Namespaced
  def self.table_name_prefix
    'namespaced_'
  end

  class Model < ActiveRecord::Base
    include Meilisearch::Rails

    meilisearch synchronous: true, index_uid: safe_index_uid(ms_index_uid({})) do
      attribute :customAttr do
        40 + another_private_value
      end
      attribute :myid do
        id
      end
      searchable_attributes ['customAttr']
    end
  end
end

class NestedItem < ActiveRecord::Base
  has_many :children, class_name: 'NestedItem', foreign_key: 'parent_id'

  include Meilisearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('NestedItem'), unless: :hidden do
    attribute :nb_children
  end

  def nb_children
    children.count
  end
end

class MisconfiguredBlock < ActiveRecord::Base
  include Meilisearch::Rails
end

class SerializedDocumentSerializer < ActiveModel::Serializer
  attributes :name
end

class SerializedDocument < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch index_uid: safe_index_uid('SerializedDocument') do
    use_serializer SerializedDocumentSerializer
  end
end

class EncodedString < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch synchronous: true, force_utf8_encoding: true, index_uid: safe_index_uid('EncodedString') do
    attribute :value do
      "\xC2\xA0\xE2\x80\xA2\xC2\xA0".force_encoding('ascii-8bit')
    end
  end
end
