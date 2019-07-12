class HomeController < ApplicationController
  layout 'subpage', except: [:index]

  def index
    @events  = Event.public_and_confirmed.upcoming
    @members = User.recent.limit(4).includes(:twitter, :facebook)
    @fellows = User.fellows.includes(:twitter, :facebook)
    @dean = User.find(ENV['DEAN_USER_ID'].to_i)
    
    @total_pledged = Plan.total_pledged
    @total_members = User.with_subscription.count
    @past_events = Event.public_and_confirmed.archive
  end

  def fellowship
    @fellows = User.fellows.includes(:twitter, :facebook)
    @alumni  = User.alumni.includes(:twitter, :facebook)
  end

  def about
  end

  def hire
  end
end
