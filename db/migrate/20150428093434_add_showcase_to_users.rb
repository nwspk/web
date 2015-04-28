class AddShowcaseToUsers < ActiveRecord::Migration
  def change
    add_column :users, :showcase, :boolean, null: false, default: false
  end
end
