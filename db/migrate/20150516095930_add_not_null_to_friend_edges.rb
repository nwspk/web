class AddNotNullToFriendEdges < ActiveRecord::Migration
  def change
    change_column :friend_edges, :from_id, :integer, null: false
    change_column :friend_edges, :to_id, :integer, null: false
  end
end
