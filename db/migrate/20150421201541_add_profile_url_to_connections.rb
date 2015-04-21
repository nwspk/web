class AddProfileUrlToConnections < ActiveRecord::Migration
  def change
    add_column :connections, :profile_url, :string
  end
end
