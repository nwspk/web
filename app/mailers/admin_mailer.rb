class AdminMailer < ApplicationMailer
  def payment_failed_email(failed_user)
    @failed_user = failed_user
    return if no_admins
    mail to: admins, subject: "Payment failed for #{failed_user.name}"
  end

  def new_member_email(new_member)
    @new_member = new_member
    return if no_admins
    mail to: admins, subject: "New member signed up: #{new_member.name}"
  end

  private

  def admins
    User.admins.pluck(:email)
  end

  def no_admins
    User.admins.count < 1
  end
end
