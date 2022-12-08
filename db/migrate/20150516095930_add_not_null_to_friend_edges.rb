class AddNotNullToFriendEdges < ActiveRecord::Migration[4.2]
  def change
    change_column :friend_edges, :from_id, :integer, null: false
    change_column :friend_edges, :to_id, :integer, null: false
  end
end
