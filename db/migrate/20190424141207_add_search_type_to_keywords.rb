class AddSearchTypeToKeywords < ActiveRecord::Migration
  def change
	add_column :keywords, :search_type, :string
  end
end
