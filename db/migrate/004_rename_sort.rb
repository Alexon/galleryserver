class RenameSort < ActiveRecord::Migration
  def self.up
    rename_column :resources, :sort, :kind
  end

  def self.down
    rename_column :resources, :kind, :sort
  end
end