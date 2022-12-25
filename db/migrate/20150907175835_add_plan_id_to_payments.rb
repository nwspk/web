class AddPlanIdToPayments < ActiveRecord::Migration[4.2]
  def change
    add_column :payments, :plan_id, :integer
  end
end
