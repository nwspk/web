class EventsController < ApplicationController
  def index
    @events = Event.public_and_confirmed.group_by { |e| e.start_at.strftime('%Y-%m-%d') }
  end
end
