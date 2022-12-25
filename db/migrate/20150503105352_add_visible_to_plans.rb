class AddVisibleToPlans < ActiveRecord::Migration[4.2]
  def change
    add_column :plans, :visible, :boolean, null: false, default: true
  end
end
