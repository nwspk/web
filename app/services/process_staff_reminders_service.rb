class ProcessStaffRemindersService
  def call
    reminders = StaffReminder.all

    reminders.each do |r|
      next unless r.due?

      m = r.pop!
      AdminMailer.staff_reminder_email(r, m).deliver_later
    end
  end
end
