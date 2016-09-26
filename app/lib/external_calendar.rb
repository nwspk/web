require 'singleton'

class ExternalCalendar
  include Singleton
  
  def client
    Google::Calendar.new({
      client_id:     ENV['GOOGLE_CLIENT_ID'], 
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      calendar:      ENV['GOOGLE_CALENDAR_ID'],
      refresh_token: ENV['GOOGLE_REFRESH_TOKEN'],
      redirect_url:  'urn:ietf:wg:oauth:2.0:oob'
    })
  end
end
