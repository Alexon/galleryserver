class AddTitle < ActiveRecord::Migration
  def self.up
    add_column :resources, :title, :string
  end

  def self.down
    remove_column :resources, :title
  end
end