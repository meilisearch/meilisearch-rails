people_specification = Models::ModelSpecification.new(
  'People',
  fields: [
    %i[first_name string],
    %i[last_name string],
    %i[card_number integer]
  ]
) do
  include Meilisearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('MyCustomPeople'), primary_key: :card_number,
              auto_remove: false do
    add_attribute :full_name
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def will_save_change_to_full_name?
    will_save_change_to_first_name? || will_save_change_to_last_name?
  end
end

Models::ActiveRecord.initialize_model(people_specification)
