class CreateNetworkNodes < ActiveRecord::Migration[8.1]
  def change
    create_table :network_nodes do |t|
      t.references :internet_map, null: false, foreign_key: true
      t.references :traceroute, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: true, foreign_key: true
      t.string :ip_address
      t.string :hostname
      t.boolean :is_private, default: false
      t.string :dedupe_key, null: false
      t.float :x
      t.float :y

      t.timestamps
    end

    add_index :network_nodes, :dedupe_key, unique: true
  end
end
