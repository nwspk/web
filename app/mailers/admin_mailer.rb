class AdminMailer < ApplicationMailer
  def payment_failed_email(failed_user)
    @failed_user = failed_user
    return if no_admins

    mail to: admins, subject: "Payment failed for #{failed_user.name}"
  end

  def new_member_email(new_member)
    @new_member = new_member
    return if no_admins && no_fellows

    mail to: admins + fellows, subject: "New member signed up: #{new_member.name}"
  end

  def new_sponsored_member(new_member)
    @new_member = new_member
    return if no_admins && no_fellows

    mail to: admins, subject: "New member applied for sponsored membership: #{new_member.name}"
  end

  def new_subscriber_email(new_subscriber)
    @new_subscriber = new_subscriber
    return if no_admins

    mail to: admins, subject: "New member became a paid subscriber: #{new_subscriber.name}"
  end

  # Safety net for the website feedback form: sent when the server-side relay
  # to the feedback Google Form couldn't confirm the response was recorded
  # (stale field mapping after a form edit, outage, timeout). This email IS
  # the submission — it exists nowhere else — so it must always send.
  def feedback_fallback_email(name, contact, incident, feedback)
    @name = name
    @contact = contact
    @incident = incident
    @feedback = feedback
    recipients = admins.presence || ['ed@newspeak.house']
    mail to: recipients, subject: 'Website feedback (Google Form relay failed)'
  end

  def staff_reminder_email(reminder, member)
    @member = member
    @reminder = reminder
    mail to: @reminder.email, subject: "Member reminder: #{@member.name}"
  end

  private

  def admins
    User.admins.pluck(:email)
  end

  def fellows
    User.fellows.pluck(:email)
  end

  def no_admins
    User.admins.count.zero?
  end

  def no_fellows
    User.fellows.count.zero?
  end
end
