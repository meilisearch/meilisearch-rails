json.extract! book, :id, :title, :author, :publisher, :genre, :publication_year, :created_at, :updated_at
json.url book_url(book, format: :json)
