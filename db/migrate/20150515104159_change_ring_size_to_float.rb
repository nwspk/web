class ChangeRingSizeToFloat < ActiveRecord::Migration[4.2]
  def change
    change_column :users, :ring_size, :float, null: true
  end
end
