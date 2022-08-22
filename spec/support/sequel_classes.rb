SEQUEL_DB = Sequel.connect(if defined?(JRUBY_VERSION)
                             'jdbc:sqlite:sequel_data.sqlite3'
                           else
                             { 'adapter' => 'sqlite',
                               'database' => 'sequel_data.sqlite3' }
                           end)

unless SEQUEL_DB.table_exists?(:sequel_books)
  SEQUEL_DB.create_table(:sequel_books) do
    primary_key :id
    String :name
    String :author
    FalseClass :released
    FalseClass :premium
  end
end

class SequelBook < Sequel::Model(SEQUEL_DB)
  plugin :active_model

  include MeiliSearch::Rails

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
