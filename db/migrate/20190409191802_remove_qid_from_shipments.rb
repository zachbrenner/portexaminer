class RemoveQidFromShipments < ActiveRecord::Migration
  def change
    remove_column :shipments, :qid, :integer
  end
end
