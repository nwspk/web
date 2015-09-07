class AddContributionToPlans < ActiveRecord::Migration
  def change
    add_column :plans, :contribution, :float, default: 0.0, null: false
  end
end
