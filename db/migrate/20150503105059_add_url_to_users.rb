class AddUrlToUsers < ActiveRecord::Migration
  def change
    add_column :users, :url, :string, null: false, default: ""
  end
end
