class EventsController < ApplicationController
  layout 'subpage'
  before_action :set_events, only: :index

  def index
    @events = @events.group_by { |e| e.start_at.strftime('%Y-%m-%d') }
  end

  private

  def set_events
    if user_signed_in? && current_user.admin_or_staff?
      @events = Event.confirmed
    else
      @events = Event.public_and_confirmed
    end
  end
end
