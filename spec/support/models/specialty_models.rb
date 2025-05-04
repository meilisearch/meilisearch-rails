Models::ActiveRecord.schema.create_table :namespaced_models do |t|
  t.string :name
  t.integer :another_private_value
end

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

nested_items_specification = Models::ModelSpecification.new(
  'NestedItem',
  fields: [
    %i[parent_id integer],
    %i[hidden boolean]
  ]
) do
  has_many :children, class_name: 'NestedItem', foreign_key: 'parent_id'

  include Meilisearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('NestedItem'), unless: :hidden do
    attribute :nb_children
  end

  def nb_children
    children.count
  end
end

Models::ActiveRecord.initialize_model(nested_items_specification)

misconfigured_blocks_specification = Models::ModelSpecification.new(
  'MisconfiguredBlock',
  fields: [%i[name string]]
) do
  include Meilisearch::Rails
end

Models::ActiveRecord.initialize_model(misconfigured_blocks_specification)

module Models
  class SerializedDocumentSerializer < ActiveModel::Serializer
    attributes :name
  end
end

serialized_documents_specification = Models::ModelSpecification.new(
  'SerializedDocument',
  fields: [
    %i[name string],
    %i[skip string]
  ]
) do
  include Meilisearch::Rails

  meilisearch index_uid: safe_index_uid('SerializedDocument') do
    use_serializer Models::SerializedDocumentSerializer
  end
end

Models::ActiveRecord.initialize_model(serialized_documents_specification)

encoded_strings_specification = Models::ModelSpecification.new(
  'EncodedString',
  fields: []
) do
  include Meilisearch::Rails

  meilisearch synchronous: true, force_utf8_encoding: true, index_uid: safe_index_uid('EncodedString') do
    attribute :value do
      "\xC2\xA0\xE2\x80\xA2\xC2\xA0".force_encoding('ascii-8bit')
    end
  end
end

Models::ActiveRecord.initialize_model(encoded_strings_specification)
