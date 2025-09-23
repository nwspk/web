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

    # Add weekly Ration Club (Wednesdays, 7–10pm)
    now_utc = Time.now.utc
    days_until_wed = (3 - now_utc.wday) % 7
    ration_start = (now_utc.to_date + days_until_wed).to_time + 19.hours
    ration_end   = ration_start + 3.hours

    cal.event do |e|
      e.dtstart     = Icalendar::Values::DateTime.new(ration_start, tzid: 'UTC')
      e.dtend       = Icalendar::Values::DateTime.new(ration_end, tzid: 'UTC')
      e.summary     = 'Ration Club'
      e.description = "Register: https://forms.gle/T3rXorsrb4gXKazv9\n\nEach week Newspeak House hosts a community dinner called Ration Club, open to anyone who'd like to find out more about the college and its work."
      e.location    = 'Newspeak House, 133 Bethnal Green Road, London, E2 7DG, UK'
      e.url         = 'https://forms.gle/T3rXorsrb4gXKazv9'
      e.rrule       = Icalendar::Values::Recur.new('FREQ=WEEKLY;BYDAY=WE')
    end

    render body: cal.to_ical, content_type: 'text/calendar'
  end
end
