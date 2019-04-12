class CreateShipments < ActiveRecord::Migration
  def change
    create_table :shipments do |t|
      t.integer :search_id
      t.text :url
      t.string :shipper
      t.string :consignee
      t.string :origin
      t.string :destination
      t.string :date

      t.timestamps null: false
    end
  end
end
