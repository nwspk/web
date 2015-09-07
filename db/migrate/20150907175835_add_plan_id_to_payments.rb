class AddPlanIdToPayments < ActiveRecord::Migration
  def change
    add_column :payments, :plan_id, :integer
  end
end
