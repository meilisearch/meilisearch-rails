enqueued_documents_specification = Models::ModelSpecification.new(
  'EnqueuedDocument',
  fields: [%i[name string]]
) do
  include Meilisearch::Rails

  include GlobalID::Identification

  def id
    read_attribute(:id)
  end

  def self.find(_id)
    EnqueuedDocument.first
  end

  meilisearch enqueue: proc { |record| raise "enqueued #{record.name}" },
              index_uid: safe_index_uid('EnqueuedDocument') do
    attributes [:name]
  end
end

Models::ActiveRecord.initialize_model(enqueued_documents_specification)

disabled_enqueued_documents_specification = Models::ModelSpecification.new(
  'DisabledEnqueuedDocument',
  fields: [%i[name string]]
) do
  include Meilisearch::Rails

  meilisearch(enqueue: proc { |_record| raise 'enqueued' },
              index_uid: safe_index_uid('EnqueuedDocument'),
              disable_indexing: true) do
    attributes [:name]
  end
end

Models::ActiveRecord.initialize_model(disabled_enqueued_documents_specification)

conditionally_enqueued_documents_specification = Models::ModelSpecification.new(
  'ConditionallyEnqueuedDocument',
  fields: [
    %i[name string],
    %i[is_public boolean]
  ]
) do
  include Meilisearch::Rails

  meilisearch(enqueue: true,
              index_uid: safe_index_uid('ConditionallyEnqueuedDocument'),
              if: :should_index?) do
    attributes %i[name is_public]
  end

  def should_index?
    is_public
  end
end

Models::ActiveRecord.initialize_model(conditionally_enqueued_documents_specification)
