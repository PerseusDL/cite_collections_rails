class AddSourceUrnToVersions < ActiveRecord::Migration
  def change
    add_column :versions, :source_urn, :string
  end
end
