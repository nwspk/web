# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def billing
    UserMailer.billing_email(User.first, 100.days.ago)
  end
end
