require 'support/active_record_schema'

ar_schema.create_table :restaurants do |t|
  t.string :name
  t.string :kind
  t.text :description
end

class Restaurant < ActiveRecord::Base
  include GlobalID::Identification
  include Meilisearch::Rails

  meilisearch index_uid: safe_index_uid('Restaurant') do
    attributes_to_crop [:description]
    crop_length 10
    pagination max_total_hits: 2
  end
end
