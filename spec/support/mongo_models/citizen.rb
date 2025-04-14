class Citizen
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :age, type: Integer

  include MeiliSearch::Rails

  meilisearch index_uid: safe_index_uid('Citizen')
end
