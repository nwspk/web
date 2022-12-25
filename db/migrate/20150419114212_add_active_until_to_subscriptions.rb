class AddActiveUntilToSubscriptions < ActiveRecord::Migration[4.2]
  def change
    add_column :subscriptions, :active_until, :timestamp
  end
end
