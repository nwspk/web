class AddVisibleToPlans < ActiveRecord::Migration
  def change
    add_column :plans, :visible, :boolean, null: false, default: true
  end
end
