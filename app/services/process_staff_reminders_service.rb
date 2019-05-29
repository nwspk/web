class ProcessStaffRemindersService
  def call
    #Ensure this key exists on the production server
    if ENV.has_key?("SEND_REMINDERS")
      StaffReminder.active.find_each do |r|
        next unless r.due?(Time.now)

        m = r.pop!
        AdminMailer.staff_reminder_email(r, m).deliver_later unless m.nil?
      end
    end
  end
end
