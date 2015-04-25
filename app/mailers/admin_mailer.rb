class AdminMailer < ApplicationMailer
  def payment_failed_email(failed_user)
    @failed_user = failed_user
    mail to: User.admins.pluck(:email), subject: "Payment failed for #{failed_user.name}"
  end
end
