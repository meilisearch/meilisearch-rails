fruits_specification = Models::ModelSpecification.new(
  'Fruit',
  fields: [%i[name string]]
) do
  include Meilisearch::Rails

  # only raise exceptions in development env
  meilisearch raise_on_failure: true, index_uid: safe_index_uid('Fruit') do
    attribute :name
  end
end

Models::ActiveRecord.initialize_model(fruits_specification)
