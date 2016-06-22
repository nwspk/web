class HomeController < ApplicationController
  layout 'subpage', except: [:index]

  def index
    @events  = Event.public_and_confirmed.upcoming.limit(3)
    @members = User.recent.limit(3)
    @fellows = User.fellows.limit(8)

    @total_pledged = Plan.all.reduce(Money.new(0, 'GBP')) { |aggr, plan| aggr + plan.value * plan.subscriptions.active.count * plan.contribution }
    @total_members = User.with_subscription.count
    @goal_percent  = (@total_pledged.cents / (200000 * 100)) * 100
  end

  def fellowship
    @fellows = User.fellows
    @alumni  = User.alumni
  end

  def about
  end

  def hire
  end
end
