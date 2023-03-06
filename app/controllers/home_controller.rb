class HomeController < ApplicationController
  layout 'subpage', except: [:index]

  def index
    @events  = Event.public_and_confirmed.upcoming
    @fellows = User.fellows
    @past_events = Event.public_and_confirmed.archive
  end

  def fellowship
    @fellows = User.fellows
    @alumni  = User.alumni
  end

  def residency
    @fellows = User.fellows
    @alumni  = User.alumni
  end

  def residents
    @fellows = User.fellows
  end
end
