require 'support/active_record_schema'

ar_schema.create_table :unconfigured_model do |t|
  t.string :name
end

class UnconfiguredModel < ActiveRecord::Base
  include MeiliSearch::Rails
end

module TestUtil
  def self.clear_unconfigured_model!
    UnconfiguredModel.clear_index!(true) if UnconfiguredModel.respond_to?(:clear_index)
    UnconfiguredModel.delete_all
  end
end
