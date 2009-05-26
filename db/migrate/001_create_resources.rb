class CreateResources < ActiveRecord::Migration
  def self.up
    create_table :resources do |t|
      t.column :kind, :string, :null => false, :default=>'image'
      t.column :sourceURL, :string
      t.column :filepath, :string, :null => false
      t.column :mimetype, :string, :null => false, :default => 'text/plain'
      t.column :tags, :string
      t.column :description, :string
      t.column :date, :datetime
      t.column :title, :string
    end
  end

  def self.down
    drop_table :resources
  end
end