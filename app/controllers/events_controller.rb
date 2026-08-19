class EventsController < ApplicationController
  layout 'subpage'

  def index
    events       = visible_events
    @events      = events.upcoming
    @past_events = events.archive

    # The selected event drives the social-preview meta tags. Looked up in the
    # whole visible scope rather than in the two lists, so a shared link keeps
    # working after the event has happened.
    @selected_event = events.find_by(id: params[:id]) if params[:id]
  end

  private

  # Events this visitor may see. The upcoming/archive split is a display
  # concern, so it lives at the call site rather than in here.
  def visible_events
    if user_signed_in? && current_user.admin_or_staff?
      Event.confirmed
    else
      Event.public_and_confirmed
    end
  end
end
