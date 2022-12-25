class AddRoleToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :role, :string, null: false, default: ""
  end
end
