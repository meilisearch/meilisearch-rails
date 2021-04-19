# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

require 'faker'

Book.destroy_all

10.times do
    Book.create(
        title: Faker::Book.title, 
        author: Faker::Book.author,
        publisher: Faker::Book.publisher,
        genre: Faker::Book.genre,
        publication_year: Faker::Number.within(range: 1800..2020)
    )
end
