class AddQidToShipments < ActiveRecord::Migration
  def change
    add_column :shipments, :qid, :integer
  end
end
