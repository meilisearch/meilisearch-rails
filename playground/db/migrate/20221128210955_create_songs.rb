class CreateSongs < ActiveRecord::Migration[6.1]
  def change
    create_table :songs do |t|
      t.string :title
      t.string :author
      t.string :writer
      t.text :lyrics

      t.timestamps
    end
  end
end
