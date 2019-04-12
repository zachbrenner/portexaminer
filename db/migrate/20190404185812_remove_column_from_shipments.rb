class RemoveColumnFromShipments < ActiveRecord::Migration
  def change
    remove_column :shipments, :search_id, :integer
  end
end
