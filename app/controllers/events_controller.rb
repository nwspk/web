class EventsController < ApplicationController
  layout 'subpage'

  def index
    if user_signed_in? && current_user.admin_or_staff?
      @events      = Event.confirmed.upcoming
      @past_events = Event.confirmed.archive
    else
      @events      = Event.public_and_confirmed.upcoming
      @past_events = Event.public_and_confirmed.archive
    end
  end
end
