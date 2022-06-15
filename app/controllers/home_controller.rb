class HomeController < ApplicationController
  layout 'subpage', except: [:index]

  def index
    @events  = Event.public_and_confirmed.upcoming
    @fellows = User.fellows
    @dean = User.find(ENV['DEAN_USER_ID'].to_i)    
    @past_events = Event.public_and_confirmed.archive
  end

  def fellowship
    @fellows = User.fellows
    @alumni  = User.alumni
  end

  def about
  end
end
