class UserMailer < ApplicationMailer
  helper  ApplicationHelper
  include ApplicationHelper

  def billing_email(user, time = Time.now)
    @user                = user
    @new_users           = User.created_after_date(time - 30.days)
    @num_users           = User.count
    @subscription        = user.subscription
    @num_connections     = @user.friends.count('distinct to_id')
    @num_new_connections = @user.friends.where('friend_edges.created_at > ?', time - 30.days).count('distinct to_id')
    @upcoming_events     = Event.public_and_confirmed.upcoming

    unless @subscription.customer_id.blank?
      stripe_customer = Stripe::Customer.retrieve(@subscription.customer_id)
      @card_num       = stripe_customer.sources.retrieve(stripe_customer.default_source).last4
    else
      @card_num = 4242
    end

    @discounted_total = @subscription.plan.value - (@user.discount / 12)

    if @discounted_total.cents < 0
      @discounted_total = Money.new(0, 'GBP')
    end

    @ascii_table = Terminal::Table.new rows: [
      ['Membership Tier:', @subscription.plan.name, positivize_zero_val(@subscription.plan.value)],
      ['Maven Discount:', "#{@num_connections} connections", positivize_zero_val(@user.discount / -12)],
      ['Total:', '', positivize_zero_val(@discounted_total)]
    ]

    @ascii_events_table = Terminal::Table.new headings: ['Day', 'Time', 'Event'], rows: @upcoming_events.map { |e| [e.start_at.strftime('%e %A %B, %Y'), e.start_at.strftime('%l:%M%P'), e.name] }

    mail to: user.email, subject: "This month at Newspeak House"
  end

  def payment_failed_email(user)
    @user = user
    mail to: user.email, subject: "Subscription charge failed"
  end
end
