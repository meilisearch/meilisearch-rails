require 'support/sequel_db'

sequel_db.create_table(:sequel_people) do
  primary_key :id
  Integer :card_number
  String :first_name
end

class SequelPerson < Sequel::Model(sequel_db)
  plugin :active_model

  include Meilisearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('SequelPerson'), primary_key: :card_number
end
