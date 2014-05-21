class CreateAuthors < ActiveRecord::Migration
  def change
    create_table :authors do |t|
      t.string :urn
      t.string :authority_name
      t.string :canonical_id
      t.string :mads_file
      t.string :alt_ids
      t.string :related_works
      t.string :urn_status
      t.string :redirect_to
      t.string :created_by
      t.string :edited_by
      t.timestamps
    end
  end
end
