class CreateTraceroutes < ActiveRecord::Migration[8.1]
  def change
    create_table :traceroutes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :internet_map, null: false, foreign_key: true
      t.string :target_domain
      t.text :raw_output
      t.integer :status, default: 0
      t.text :error_message

      t.timestamps
    end

    add_index :traceroutes, :status
  end
end
