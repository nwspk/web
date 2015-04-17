class CreatePlans < ActiveRecord::Migration
  def change
    create_table :plans do |t|
      t.string :name, null: false, default: ""
      t.string :stripe_id, null: false, default: ""
      t.integer :value, null: false, default: 0

      t.timestamps null: false
    end
  end
end
