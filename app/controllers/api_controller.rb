require 'icalendar/tzinfo'

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

  def dividends
    start_date = Chronic::parse(params[:from] || '30 days ago')
    end_date   = Chronic::parse(params[:to]   || 'today')

    s = CalculatePayrollService.new

    dividend = s.call(start_date, end_date)
    dividend = Money.new(dividend, 'GBP').format

    str = "Total dividends\n#{dividend}"

    respond_to do |format|
      format.csv { render body: str, content_type: 'text/csv' }
    end
  end

  def events
    cal = Icalendar::Calendar.new
    # tz  = TZInfo::Timezone.get 'UTC'
    # timezone = tz.ical_timezone Time.now.utc
    # cal.add_timezone timezone

    Event.public_and_confirmed.each do |ev|
      cal.event do |e|
        e.dtstart     = Icalendar::Values::DateTime.new(ev.start_at.to_datetime.change(offset: '+1000'), tzid: 'UTC')
        e.dtend       = Icalendar::Values::DateTime.new(ev.end_at.to_datetime.change(offset: '+1000'), tzid: 'UTC')
        e.summary     = ev.name
        e.description = ev.description
        e.location    = 'Newspeak House, 133 Bethnal Green Road, London, E2 7DG, UK'
        e.url         = ev.url
        e.organizer   = Icalendar::Values::CalAddress.new("mailto:#{ev.organiser_email}", cn: ev.organiser_name)
      end
    end

    render body: cal.to_ical, content_type: 'text/calendar'
  end
end
