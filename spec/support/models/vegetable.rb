require 'support/active_record_schema'

ar_schema.create_table :vegetables do |t|
  t.string :name
end

class Vegetable < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch raise_on_failure: false, index_uid: safe_index_uid('Fruit') do
    attribute :name
  end
end
