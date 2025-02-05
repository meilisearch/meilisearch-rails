require 'support/active_record_schema'

ar_schema.create_table :cats do |t|
  t.string :name
end

ar_schema.create_table :dogs do |t|
  t.string :name
end

class Cat < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch index_uid: safe_index_uid('animals'), synchronous: true, primary_key: :ms_id

  private

  def ms_id
    "cat_#{id}"
  end
end

class Dog < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch index_uid: safe_index_uid('animals'), synchronous: true, primary_key: :ms_id

  private

  def ms_id
    "dog_#{id}"
  end
end

module TestUtil
  def self.reset_animals!
    Cat.clear_index!(true)
    Cat.delete_all
    Dog.clear_index!(true)
    Dog.delete_all
  end
end
