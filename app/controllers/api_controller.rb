require 'icalendar'
require 'icalendar/tzinfo'
require 'tzinfo'

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
    # Hint to clients (including Apple Calendar) that the calendar's canonical timezone is Europe/London
    cal.append_custom_property('X-WR-CALNAME', 'Newspeak House Events')
    cal.append_custom_property('X-WR-TIMEZONE', 'Europe/London')


    Event.public_and_confirmed.each do |ev|
      cal.event do |e|
        e.dtstart     = Icalendar::Values::DateTime.new(ev.start_at.utc, tzid: 'UTC')
        e.dtend       = Icalendar::Values::DateTime.new(ev.end_at.utc, tzid: 'UTC')
        e.summary     = ev.name
        e.description = "Register: #{ev.url}\n\n#{ev.description_plaintext}"
        e.location    = 'Newspeak House, 133 Bethnal Green Road, London, E2 7DG, UK'
        e.url         = ev.url
        e.organizer   = Icalendar::Values::CalAddress.new("mailto:#{ev.organiser_email}", cn: ev.organiser_name)
      end
    end

    # Add weekly Ration Club (Wednesdays, 7–10pm London time) with a one-off special edition on 2026-05-13.
    now_london = Time.zone.now.in_time_zone('Europe/London')
    special_ration_date = Date.new(2026, 5, 13)

    if now_london.to_date <= special_ration_date
      special_ration_start = now_london.change(
        year: 2026, month: 5, day: 13, hour: 19, min: 0, sec: 0
      )
      special_ration_end = special_ration_start + 3.hours

      cal.event do |e|
        e.dtstart     = Icalendar::Values::DateTime.new(special_ration_start, tzid: 'Europe/London')
        e.dtend       = Icalendar::Values::DateTime.new(special_ration_end, tzid: 'Europe/London')
        e.summary     = "Ration Club - Cohort Reunion ('24 & '25)"
        e.description = "Register: https://luma.com/vocnx4on\n\nSpecial edition: Ration Club Cohort Reunion ('24 & '25) at Newspeak House."
        e.location    = 'Newspeak House, 133 Bethnal Green Road, London, E2 7DG, UK'
        e.url         = 'https://luma.com/vocnx4on'
      end
    end

    days_until_wed = (3 - now_london.wday) % 7
    wednesday = (now_london + days_until_wed.days)
    wednesday += 7.days if wednesday.to_date <= special_ration_date

    ration_start = wednesday.change(hour: 19, min: 0, sec: 0)
    ration_end = ration_start + 3.hours

    cal.event do |e|
      e.dtstart     = Icalendar::Values::DateTime.new(ration_start, tzid: 'Europe/London')
      e.dtend       = Icalendar::Values::DateTime.new(ration_end, tzid: 'Europe/London')
      e.summary     = 'Ration Club'
      e.description = "Register: https://forms.gle/T3rXorsrb4gXKazv9\n\nEach week Newspeak House hosts a community dinner called Ration Club, open to anyone who'd like to find out more about the college and its work."
      e.location    = 'Newspeak House, 133 Bethnal Green Road, London, E2 7DG, UK'
      e.url         = 'https://forms.gle/T3rXorsrb4gXKazv9'
      e.rrule       = Icalendar::Values::Recur.new('FREQ=WEEKLY;BYDAY=WE')
    end

    render body: cal.to_ical, content_type: 'text/calendar'
  end
end
