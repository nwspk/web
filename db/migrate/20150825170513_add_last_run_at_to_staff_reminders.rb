class AddLastRunAtToStaffReminders < ActiveRecord::Migration[4.2]
  def change
    add_column :staff_reminders, :last_run_at, :datetime
  end
end
