require 'support/active_record_schema'

ar_schema.create_table :colors do |t|
  t.string :name
  t.string :short_name
  t.integer :hex
end

class Color < ActiveRecord::Base
  include Meilisearch::Rails
  attr_accessor :not_indexed

  meilisearch synchronous: true, index_uid: safe_index_uid('Color') do
    searchable_attributes [:name]
    filterable_attributes ['short_name']
    sortable_attributes [:name]
    ranking_rules [
      'words',
      'typo',
      'proximity',
      'attribute',
      'sort',
      'exactness',
      'hex:asc'
    ]
    attributes_to_highlight [:name]
    faceting max_values_per_facet: 20
    proximity_precision 'byWord'
  end

  def will_save_change_to_hex?
    false
  end

  def will_save_change_to_short_name?
    false
  end
end

module TestUtil
  def self.reset_colors!
    Color.clear_index!(true)
    Color.delete_all
  end
end
