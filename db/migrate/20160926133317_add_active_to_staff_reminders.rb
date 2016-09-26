class AddActiveToStaffReminders < ActiveRecord::Migration
  def change
    add_column :staff_reminders, :active, :boolean
  end
end
