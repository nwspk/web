class AddRingSizeToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :ring_size, :integer, null: true
  end
end
