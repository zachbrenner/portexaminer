class RemoveJobIdFromShipments < ActiveRecord::Migration
  def change
    remove_column :searches, :job_id, :string
  end
end
