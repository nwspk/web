class AddUrlToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :url, :string, null: false, default: ""
  end
end
