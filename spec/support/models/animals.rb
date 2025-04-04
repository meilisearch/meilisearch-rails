require 'support/active_record_schema'

cats_specification = Models::ModelSpecification.new(
  'Cat',
  fields: [%i[name string]]
) do
  include Meilisearch::Rails

  meilisearch index_uid: safe_index_uid('animals'), synchronous: true, primary_key: :ms_id

  private

  def ms_id
    "cat_#{id}"
  end
end

dogs_specification = Models::ModelSpecification.new(
  'Dog',
  fields: [%i[name string]]
) do
  include Meilisearch::Rails

  meilisearch index_uid: safe_index_uid('animals'), synchronous: true, primary_key: :ms_id

  private

  def ms_id
    "dog_#{id}"
  end
end

Models::ActiveRecord.initialize_model(cats_specification)
Models::ActiveRecord.initialize_model(dogs_specification)
