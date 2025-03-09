require 'support/active_record_schema'

ar_schema.create_table :books do |t|
  t.string :name
  t.string :author
  t.boolean :premium
  t.boolean :released
  t.string :genre
end

class Book < ActiveRecord::Base
  include Meilisearch::Rails

  meilisearch synchronous: true, index_uid: safe_index_uid('SecuredBook'), sanitize: true do
    searchable_attributes [:name]
    typo_tolerance min_word_size_for_typos: { one_typo: 5, twoTypos: 8 }
    filterable_attributes %i[genre author]
    faceting max_values_per_facet: 3

    add_index safe_index_uid('BookAuthor') do
      searchable_attributes [:author]
    end

    add_index safe_index_uid('Book'), if: :public? do
      searchable_attributes [:name]
    end
  end

  private

  def public?
    released && !premium
  end
end

module TestUtil
  def self.reset_books!
    Book.clear_index!(true)
    Book.index(safe_index_uid('BookAuthor')).delete_all_documents
    Book.index(safe_index_uid('Book')).delete_all_documents
  end
end
