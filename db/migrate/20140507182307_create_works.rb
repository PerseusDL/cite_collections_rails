class CreateWorks < ActiveRecord::Migration
  def change
    create_table :works do |t|
      t.string :urn
      t.string :work
      t.text :title_eng
      t.text :notes
      t.string :urn_status
      t.string :created_by
      t.string :edited_by
      t.timestamps
    end
  end
end
