class AddProfileUrlToConnections < ActiveRecord::Migration[4.2]
  def change
    add_column :connections, :profile_url, :string
  end
end
