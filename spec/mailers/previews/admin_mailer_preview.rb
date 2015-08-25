# Preview all emails at http://localhost:3000/rails/mailers/admin_mailer
class AdminMailerPreview < ActionMailer::Preview
  def staff_reminder
    AdminMailer.staff_reminder_email(StaffReminder.new(email: 'foo@bar', frequency: 6), User.first)
  end
end
