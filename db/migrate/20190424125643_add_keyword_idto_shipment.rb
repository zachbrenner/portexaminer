class AddKeywordIdtoShipment < ActiveRecord::Migration
  def change
	add_column :shipments, :keyword_id, :string
  end
end
