class CreateStaffReminders < ActiveRecord::Migration
  def change
    create_table :staff_reminders do |t|
      t.string :email, :string, null: false, default: ""
      t.integer :frequency
      t.integer :last_id

      t.timestamps null: false
    end
  end
end
