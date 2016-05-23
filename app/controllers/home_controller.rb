class HomeController < ApplicationController
  def index
    @events  = Event.public_and_confirmed.limit(3)
    @members = User.with_subscription.limit(3)
    @fellows = User.fellows.limit(8)

    @total_pledged = Plan.all.reduce(Money.new(0, 'GBP')) { |aggr, plan| aggr + plan.value * plan.subscriptions.count * plan.contribution }
    @total_members = User.with_subscription.count
  end

  def fellowship
  end

  def contact
  end

  def calendar
    redirect_to "https://hackpad.com/Newspeak-House-Events-Calendar-uNKMeHocJE9"
  end
end
