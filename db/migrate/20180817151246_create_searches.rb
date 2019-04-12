class CreateSearches < ActiveRecord::Migration
  def change
    create_table :searches do |t|
      t.string :job_id
      t.string :keywords

      t.timestamps null: false
    end
  end
end
