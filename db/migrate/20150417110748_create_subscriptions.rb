class CreateSubscriptions < ActiveRecord::Migration
  def change
    create_table :subscriptions do |t|
      t.belongs_to :user, unique: true
      t.string :customer_id, null: false, default: ""
      t.string :subscription_id, null: false, default: ""
      t.belongs_to :plan, index: true

      t.timestamps null: false
    end
  end
end
