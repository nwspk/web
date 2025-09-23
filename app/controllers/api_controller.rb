require 'icalendar'

class ApiController < ApplicationController
  protect_from_forgery with: :null_session

  rescue_from ActiveRecord::RecordNotFound do
    render json: { status: :no }, status: 401
  end

  def uid
    uid  = params[:uid]
    ring = Ring.find_by! uid: uid

    if ring.eligible_for_entry?
      response = { status: :ok }
      ring.record_entry!
      render json: response, status: 200
    else
      response = { status: :no }
      render json: response, status: 401
    end
  end

  def events
    cal = Icalendar::Calendar.new

    Event.public_and_confirmed.each do |ev|
      cal.event do |e|
        e.dtstart     = Icalendar::Values::DateTime.new(ev.start_at.utc, tzid: 'UTC')
        e.dtend       = Icalendar::Values::DateTime.new(ev.end_at.utc, tzid: 'UTC')
        e.summary     = ev.name
        e.description = "Register: #{ev.url}\n\n#{ev.description}"
        e.location    = 'Newspeak House, 133 Bethnal Green Road, London, E2 7DG, UK'
        e.url         = ev.url
        e.organizer   = Icalendar::Values::CalAddress.new("mailto:#{ev.organiser_email}", cn: ev.organiser_name)
      end
    end

    render body: cal.to_ical, content_type: 'text/calendar'
  end
end
