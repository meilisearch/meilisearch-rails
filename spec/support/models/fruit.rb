require 'support/active_record_schema'

ar_schema.create_table :fruits do |t|
  t.string :name
end

class Fruit < ActiveRecord::Base
  include Meilisearch::Rails

  # only raise exceptions in development env
  meilisearch raise_on_failure: true, index_uid: safe_index_uid('Fruit') do
    attribute :name
  end
end
