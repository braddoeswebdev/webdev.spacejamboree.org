class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.integer :asn
      t.string :name
      t.string :org_domain
      t.string :color
      t.boolean :seeded, default: false

      t.timestamps
    end

    add_index :organizations, :asn, unique: true
  end
end
