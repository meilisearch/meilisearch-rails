require 'support/sequel_db'

sequel_db.create_table(:sequel_books) do
  primary_key :id
  String :name
  String :author
  FalseClass :released
  FalseClass :premium
end

class SequelBook < Sequel::Model(sequel_db)
  plugin :active_model

  include Meilisearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('SequelBook'), sanitize: true do
    add_attribute :test
    add_attribute :test2

    searchable_attributes [:name]
  end

  def after_create
    SequelBook.new
  end

  def test
    'test'
  end

  def test2
    'test2'
  end

  private

  def public?
    released && !premium
  end
end
