class CreateNetworkLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :network_links do |t|
      t.references :traceroute, null: false, foreign_key: true
      t.references :start_node, null: false, foreign_key: { to_table: :network_nodes }
      t.references :end_node, null: false, foreign_key: { to_table: :network_nodes }
      t.integer :hop_number
      t.text :rtt_samples
      t.boolean :timed_out, default: false
      t.boolean :spans_gap, default: false

      t.timestamps
    end
  end
end
