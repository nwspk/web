class UserMailer < ApplicationMailer
  helper  ApplicationHelper
  include ApplicationHelper

  def billing_email(user, time = Time.now)
    @user                = user
    @new_users           = User.recent.created_after_date(time - 30.days)
    @num_users           = User.count
    @subscription        = user.subscription
    @num_connections     = @user.friends.count('distinct to_id')
    @num_new_connections = @user.friends.where('friend_edges.created_at > ?', time - 30.days).count('distinct to_id')
    @upcoming_events     = Event.public_and_confirmed.upcoming
    @fellows             = User.fellows
    @total_amount        = @subscription.plan.value.to_f / 100
    @vat_amount          = ( (@total_amount * 0.2)  / 1.2).round(2)
    @net_amount          = (@total_amount - @vat_amount) .round(2)
    
    unless @subscription.customer_id.blank?
      stripe_customer = Stripe::Customer.retrieve(@subscription.customer_id)
      @card_num       = stripe_customer.sources.retrieve(stripe_customer.default_source).last4
    else
      @card_num = 4242
    end
    @ascii_table = Terminal::Table.new rows: [
      ['Membership Tier:', (@subscription.plan.try(:name) || 'None'), @subscription.plan.try(:money_value)],
      ['Total:', '', @subscription.plan.try(:money_value)]
    ]
    mail to: user.email, subject: "This month at Newspeak House"
  end

  def payment_failed_email(user)
    @user = user
    mail to: user.email, subject: "Subscription charge failed"
  end
end
