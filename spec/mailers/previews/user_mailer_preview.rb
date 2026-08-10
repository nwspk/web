# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def billing
    UserMailer.billing_email(sample_user)
  end

  def payment_failed
    UserMailer.payment_failed_email(sample_user)
  end

  private

  # Use a real user when the dev database has one with a plan; otherwise
  # build an in-memory stand-in so the preview always renders.
  def sample_user
    user = User.first
    return user if user&.subscription&.plan

    user = User.new(name: 'Sample Member', email: 'member@example.com')
    user.subscription = Subscription.new(plan: Plan.new(name: 'Standard', value: 4000), customer_id: '')
    user
  end
end
