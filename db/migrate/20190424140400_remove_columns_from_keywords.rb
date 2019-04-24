class RemoveColumnsFromKeywords < ActiveRecord::Migration
  def change
	remove_column :keywords, :search_id, :integer
	remove_column :keywords, :shipment_id, :integer
  end
end
