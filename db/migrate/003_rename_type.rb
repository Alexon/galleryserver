class RenameType < ActiveRecord::Migration
  def self.up
    rename_column :resources, :type, :sort
  end

  def self.down
    rename_column :resources, :sort, :type
  end
end