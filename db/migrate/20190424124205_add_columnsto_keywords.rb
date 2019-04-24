class AddColumnstoKeywords < ActiveRecord::Migration
  def change
	add_column :keywords, :search_id, :integer
	add_column :keywords, :shipment_id, :integer
  end
end
