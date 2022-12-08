class AddActiveToStaffReminders < ActiveRecord::Migration[4.2]
  def change
    add_column :staff_reminders, :active, :boolean
  end
end
