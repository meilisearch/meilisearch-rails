class CreateAuthors < ActiveRecord::Migration[6.1]
  def change
    create_table :authors do |t|
      t.string :name

      t.timestamps
    end

    remove_column :songs, :author, :string
    add_column :songs, :author_id, :integer
  end
end
