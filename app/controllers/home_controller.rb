class HomeController < ApplicationController
  layout 'subpage', except: [:index]

  def index
    @events  = Event.public_and_confirmed.upcoming.limit(3)
    @members = User.recent.limit(4)
    @fellows = User.fellows.limit(8)

    @total_pledged = Plan.total_pledged
    @total_members = User.with_subscription.count
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
