class UserMailer < ApplicationMailer
  helper ApplicationHelper
  include ApplicationHelper

  def billing_email(user, time = Time.now)
    @user = user
    @new_users = User.recent.created_after_date(time - 30.days)
    @num_users = User.count
    @subscription = user.subscription
    @upcoming_events = Event.public_and_confirmed.upcoming
    @fellows = User.fellows
    @total_amount = @subscription.plan.value.to_f / 100
    @vat_amount = (@total_amount / 1.2).round(2)
    @net_amount = (@total_amount - @vat_amount).round(2)

    if @subscription.customer_id.present?
      stripe_customer = Stripe::Customer.retrieve(@subscription.customer_id)
      @card_num = Stripe::Customer.retrieve_source(@subscription.customer_id, stripe_customer.default_source).last4
    else
      @card_num = 4242
    end
    @ascii_table = Terminal::Table.new rows: [
      ['Membership Tier:', (@subscription.plan.try(:name) || 'None'), @subscription.plan.try(:money_value)],
      ['Total:', '', @subscription.plan.try(:money_value)]
    ]
    mail to: user.email, subject: 'This month at Newspeak House'
  end

  def payment_failed_email(user)
    @user = user
    mail to: user.email, subject: 'Subscription charge failed'
  end
end
