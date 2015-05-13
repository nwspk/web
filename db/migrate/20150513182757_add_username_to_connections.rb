class AddUsernameToConnections < ActiveRecord::Migration
  def change
    add_column :connections, :username, :string, null: false, default: ""
  end
end
