colors_specification = Models::ModelSpecification.new(
  'Color',
  fields: [
    %i[name string],
    %i[short_name string],
    %i[hex integer]
  ]
) do
  include Meilisearch::Rails
  attr_accessor :not_indexed

  meilisearch synchronous: true, index_uid: safe_index_uid('Color') do
    searchable_attributes [:name]
    filterable_attributes ['short_name']
    sortable_attributes [:name]
    ranking_rules [
      'words',
      'typo',
      'proximity',
      'attribute',
      'sort',
      'exactness',
      'hex:asc'
    ]
    attributes_to_highlight [:name]
    faceting max_values_per_facet: 20
    proximity_precision 'byWord'
  end

  def will_save_change_to_hex?
    false
  end

  def will_save_change_to_short_name?
    false
  end
end

Models::ActiveRecord.initialize_model(colors_specification)
