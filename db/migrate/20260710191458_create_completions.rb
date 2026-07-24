class CreateCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :completions do |t|
      t.references :requirement, null: false, foreign_key: true
      t.references :participation, null: false, foreign_key: true
      t.boolean :complete, default: false, null: false
      t.index [ :requirement_id, :participation_id ], unique: true

      t.timestamps
    end
  end
end
