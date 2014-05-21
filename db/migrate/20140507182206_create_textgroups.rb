class CreateTextgroups < ActiveRecord::Migration
  def change
    create_table :textgroups do |t|
      t.string :urn
      t.string :textgroup
      t.string :groupname_eng
      t.string :has_mads
      t.string :mads_possible
      t.text :notes
      t.string :urn_status
      t.string :created_by
      t.string :edited_by
      t.timestamps
    end
  end
end
