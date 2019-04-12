class CreateSearchShipment < ActiveRecord::Migration
  def change
    create_table :search_shipments do |t|
      t.integer :search_id, null: false
      t.integer :shipment_id, null: false
    end
  end
end
