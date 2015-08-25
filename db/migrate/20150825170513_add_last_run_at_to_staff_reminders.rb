class AddLastRunAtToStaffReminders < ActiveRecord::Migration
  def change
    add_column :staff_reminders, :last_run_at, :datetime
  end
end
