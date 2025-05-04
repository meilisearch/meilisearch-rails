songs_specification = Models::ModelSpecification.new(
  'Song',
  fields: [
    %i[name string],
    %i[artist string],
    %i[released boolean],
    %i[premium boolean]
  ]
) do
  include Meilisearch::Rails

  meilisearch index_uid: safe_index_uid('PrivateSongs') do
    searchable_attributes %i[name artist]

    add_index safe_index_uid('Songs'), if: :public? do
      searchable_attributes %i[name artist]
    end

    proximity_precision 'byAttribute'
  end

  private

  def public?
    released && !premium
  end
end

Models::ActiveRecord.initialize_model(songs_specification)
