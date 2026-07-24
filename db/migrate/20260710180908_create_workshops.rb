class CreateWorkshops < ActiveRecord::Migration[8.1]
  def change
    create_table :workshops do |t|
      t.string :name
      t.references :instructor, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
