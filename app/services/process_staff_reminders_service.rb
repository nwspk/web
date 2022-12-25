class ProcessStaffRemindersService
  def call
    if ENV.key?('SEND_REMINDERS')
      StaffReminder.active.find_each do |r|
        next unless r.due?(Time.now)

        m = r.pop!
        AdminMailer.staff_reminder_email(r, m).deliver_later unless m.nil?
      end
    end
  end
end
