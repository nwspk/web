class EventsController < ApplicationController
  layout 'subpage'
  before_action :set_events, only: :index

  def index
    @event = Event.public_and_confirmed.upcoming
  end

  private

  def set_events
    if user_signed_in? && current_user.admin_or_staff?
      @event = Event.confirmed.upcoming
    else
      @event = Event.public_and_confirmed.upcoming
    end
  end
end
