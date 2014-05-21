class CreateVersions < ActiveRecord::Migration
  def change
    create_table :versions do |t|
      t.string :urn
      t.string :version
      t.text :label_eng
      t.text :desc_eng
      t.string :ver_type
      t.string :has_mods
      t.string :urn_status
      t.string :redirect_to
      t.string :member_of
      t.string :created_by
      t.string :edited_by
      t.timestamps
    end
  end
end
