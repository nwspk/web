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

    # Selected event drives the social-preview meta tags, so search past
    # events too — shared links keep working after the event has happened.
    if params[:id]
      id = params[:id].to_i
      @selected_event = @events.where(id: id).take || @past_events.where(id: id).take
    end
  end
end
