class CreateRequirements < ActiveRecord::Migration[8.1]
  def change
    create_table :requirements do |t|
      t.string :name
      t.references :badge, null: false, foreign_key: true

      t.timestamps
    end
  end
end
