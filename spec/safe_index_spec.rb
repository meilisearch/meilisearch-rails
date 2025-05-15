require 'support/models/book'

describe Meilisearch::Rails::SafeIndex do
  describe '#facet_search' do
    it 'accepts all params without error' do
      TestUtil.reset_books!

      genres = %w[Legend Fiction Crime].cycle
      authors = %w[A B C].cycle

      Book.insert_all(Array.new(5) { { name: Faker::Book.title, author: authors.next, genre: genres.next } }) # rubocop:disable Rails/SkipsModelValidations
      Book.reindex!

      expect do
        Book.index.facet_search('genre', 'Fic', filter: 'author = A')
        Book.index.facet_search('genre', filter: 'author = A')
        Book.index.facet_search('genre')
      end.not_to raise_error
    end
  end
end
