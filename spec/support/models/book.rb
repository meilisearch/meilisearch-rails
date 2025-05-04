book_specification = Models::ModelSpecification.new(
  'Book',
  fields: [
    %i[name string],
    %i[author string],
    %i[premium boolean],
    %i[released boolean],
    %i[genre string]
  ]
) do
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

Models::ActiveRecord.initialize_model(book_specification)

# class Book < ActiveRecord::Base
#   include Meilisearch::Rails
#
#   meilisearch synchronous: true, index_uid: safe_index_uid('SecuredBook'), sanitize: true do
#     searchable_attributes [:name]
#     typo_tolerance min_word_size_for_typos: { one_typo: 5, twoTypos: 8 }
#     filterable_attributes %i[genre author]
#     faceting max_values_per_facet: 3
#
#     add_index safe_index_uid('BookAuthor') do
#       searchable_attributes [:author]
#     end
#
#     add_index safe_index_uid('Book'), if: :public? do
#       searchable_attributes [:name]
#     end
#   end
#
#   private
#
#   def public?
#     released && !premium
#   end
# end

# module TestUtil
#   def self.reset_books!
#     Book.clear_index!(true)
#     Book.index(safe_index_uid('BookAuthor')).delete_all_documents
#     Book.index(safe_index_uid('Book')).delete_all_documents
#   end
# end
