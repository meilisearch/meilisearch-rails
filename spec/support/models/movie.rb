movies_specification = Models::ModelSpecification.new(
  'Movie',
  fields: [%i[title string]]
) do
  include Meilisearch::Rails

  meilisearch index_uid: safe_index_uid('Movie') do
    pagination max_total_hits: 5
    typo_tolerance enabled: false
  end
end

Models::ActiveRecord.initialize_model(movies_specification)
