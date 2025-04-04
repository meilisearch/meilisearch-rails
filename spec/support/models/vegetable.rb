vegetables_specification = Models::ModelSpecification.new(
  'Vegetable',
  fields: [%i[name string]]
) do
  include Meilisearch::Rails

  meilisearch raise_on_failure: false, index_uid: safe_index_uid('Fruit') do
    attribute :name
  end
end

Models::ActiveRecord.initialize_model(vegetables_specification)
