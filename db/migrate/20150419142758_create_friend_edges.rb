class CreateFriendEdges < ActiveRecord::Migration
  def change
    create_table :friend_edges do |t|
      t.belongs_to :from, index: true
      t.belongs_to :to, index: true

      t.string :network, null: false, default: ""

      t.timestamps null: false
    end
  end
end
