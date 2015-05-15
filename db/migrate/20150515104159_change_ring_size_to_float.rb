class ChangeRingSizeToFloat < ActiveRecord::Migration
  def change
    change_column :users, :ring_size, :float, null: true
  end
end
