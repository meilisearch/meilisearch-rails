require 'support/active_record_schema'

ar_schema.create_table :people do |t|
  t.string :first_name
  t.string :last_name
  t.integer :card_number
end

class People < ActiveRecord::Base
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

module TestUtil
  def self.reset_people!
    People.clear_index!(true)
    People.delete_all
  end
end
