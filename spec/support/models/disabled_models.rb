disabled_booleans_specification = Models::ModelSpecification.new(
  'DisabledBoolean',
  fields: [%i[name string]]
) do
  include Meilisearch::Rails

  meilisearch synchronous: true, disable_indexing: true, index_uid: safe_index_uid('DisabledBoolean')
end

Models::ActiveRecord.initialize_model(disabled_booleans_specification)

disabled_procs_specification = Models::ModelSpecification.new(
  'DisabledProc',
  fields: [%i[name string]]
) do
  include Meilisearch::Rails

  meilisearch synchronous: true, disable_indexing: proc { true }, index_uid: safe_index_uid('DisabledProc')
end

Models::ActiveRecord.initialize_model(disabled_procs_specification)

disabled_symbols_specification = Models::ModelSpecification.new(
  'DisabledSymbol',
  fields: [%i[name string]]
) do
  include Meilisearch::Rails

  meilisearch synchronous: true, disable_indexing: :truth, index_uid: safe_index_uid('DisabledSymbol')

  def self.truth
    true
  end
end

Models::ActiveRecord.initialize_model(disabled_symbols_specification)
