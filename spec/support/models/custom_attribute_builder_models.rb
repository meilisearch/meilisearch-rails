require 'support/active_record_schema'

ar_schema.create_table :search_blob_from_attribute_models do |t|
  t.string :name
end

ar_schema.create_table :search_blob_from_add_attribute_models do |t|
  t.string :name
end

class SearchBlobFromAttributeModel < ActiveRecord::Base
  include Meilisearch::Rails

  class << self
    attr_accessor :search_blob_evaluations
  end

  self.search_blob_evaluations = 0

  meilisearch synchronous: true, index_uid: safe_index_uid('SearchBlobFromAttributeModel') do
    attribute :search_blob do
      self.class.search_blob_evaluations += 1
      "#{name}--#{self.class.search_blob_evaluations}"
    end

    searchable_attributes ['search_blob']
  end

  def self.reset_evaluations!
    self.search_blob_evaluations = 0
  end

  def will_save_change_to_search_blob?
    will_save_change_to_name?
  end
end

class SearchBlobFromAddAttributeModel < ActiveRecord::Base
  include Meilisearch::Rails

  class << self
    attr_accessor :search_blob_evaluations
  end

  self.search_blob_evaluations = 0

  meilisearch synchronous: true, index_uid: safe_index_uid('SearchBlobFromAddAttributeModel') do
    attribute :name

    add_attribute :search_blob do
      self.class.search_blob_evaluations += 1
      "#{name}--#{self.class.search_blob_evaluations}"
    end

    searchable_attributes ['name']
  end

  def self.reset_evaluations!
    self.search_blob_evaluations = 0
  end

  def will_save_change_to_search_blob?
    will_save_change_to_name?
  end
end

module TestUtil
  def self.reset_search_blob_from_attribute_models!
    SearchBlobFromAttributeModel.clear_index!
    SearchBlobFromAttributeModel.delete_all
    SearchBlobFromAttributeModel.reset_evaluations!
  end

  def self.reset_search_blob_from_add_attribute_models!
    SearchBlobFromAddAttributeModel.clear_index!
    SearchBlobFromAddAttributeModel.delete_all
    SearchBlobFromAddAttributeModel.reset_evaluations!
  end
end
