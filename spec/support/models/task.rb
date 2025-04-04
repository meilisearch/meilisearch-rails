tasks_specification = Models::ModelSpecification.new(
  'Task',
  fields: [%i[title string]]
) do
  include Meilisearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('Task')
end

Models::ActiveRecord.initialize_model(tasks_specification)
