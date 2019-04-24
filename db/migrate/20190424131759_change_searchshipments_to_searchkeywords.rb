class ChangeSearchshipmentsToSearchkeywords < ActiveRecord::Migration
  def change
	remove_column :search_shipments, :shipment_id, :integer
	rename_table :search_shipments, :search_keywords
	add_column :search_keywords, :keyword_id, :integer, null: false
  end
end
