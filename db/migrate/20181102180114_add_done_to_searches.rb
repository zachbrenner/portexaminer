class AddDoneToSearches < ActiveRecord::Migration
  def change
    add_column :searches, :done, :boolean
  end
end
