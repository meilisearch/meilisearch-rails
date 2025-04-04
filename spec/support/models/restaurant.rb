restaurants_specification = Models::ModelSpecification.new(
  'Restaurant',
  fields: [
    %i[name string],
    %i[kind string],
    %i[description text]
  ]
) do
  include GlobalID::Identification
  include Meilisearch::Rails

  meilisearch index_uid: safe_index_uid('Restaurant') do
    attributes_to_crop [:description]
    crop_length 10
    pagination max_total_hits: 2
  end
end

Models::ActiveRecord.initialize_model(restaurants_specification)
