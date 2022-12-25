class AddShowcaseToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :showcase, :boolean, null: false, default: false
  end
end
