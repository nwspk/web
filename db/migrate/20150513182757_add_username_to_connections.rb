class AddUsernameToConnections < ActiveRecord::Migration[4.2]
  def change
    add_column :connections, :username, :string, null: false, default: ""
  end
end
