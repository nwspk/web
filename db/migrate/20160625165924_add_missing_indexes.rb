class AddMissingIndexes < ActiveRecord::Migration[4.2]
  def change
    add_index :addresses, :user_id
    add_index :subscriptions, :user_id
    add_index :payments, :plan_id
    add_index :events, :start_at
    add_index :events, :end_at
  end
end
