class AddRingSizeToUsers < ActiveRecord::Migration
  def change
    add_column :users, :ring_size, :integer, null: true
  end
end
