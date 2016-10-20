namespace :calendar do
  desc 'Generate authorization URL for Google Calendar API'
  task :authorize_url => :environment do
    cal = ExternalCalendar.instance.client
    puts 'Paste the following URL into your browser:'
    puts cal.authorize_url
    puts 'Then pass the access code you get into `rake "calendar:refresh_token[THE CODE HERE]"`'
  end

  desc 'Generate refresh token based on given access code'
  task :refresh_token, [:access_code] => :environment do |_, args|
    access_code = args.access_code
    cal = ExternalCalendar.instance.client
    puts "Logging you in with the access code: #{access_code}"
    puts 'Set the following token as GOOGLE_REFRESH_TOKEN in the environment'
    puts cal.login_with_auth_code access_code
  end

  desc 'Upload all events to Google Calendar'
  task :sync => :environment do
    cal = ExternalCalendar.instance.client

    Event.public_and_confirmed.find_each do |db_event|
      escaped_desc = db_event.description.to_json
      escaped_desc.gsub!(/\A"|"\Z/, '')

      if db_event.gcal_id.nil?
        gc_event = cal.create_event do |e|
          e.title       = db_event.name
          e.start_time  = db_event.start_at.to_datetime.change(offset: '+1000')
          e.end_time    = db_event.end_at.to_datetime.change(offset: '+1000')
          e.description = escaped_desc
          e.location    = 'Newspeak House, 133 Bethnal Green Road, London, E2 7DG, UK'
        end

        db_event.update(gcal_id: gc_event.id)
      else
        cal.find_or_create_event_by_id(db_event.gcal_id) do |e|
          e.title       = db_event.name
          e.start_time  = db_event.start_at.to_datetime.change(offset: '+1000')
          e.end_time    = db_event.end_at.to_datetime.change(offset: '+1000')
          e.description = escaped_desc
          e.location    = 'Newspeak House, 133 Bethnal Green Road, London, E2 7DG, UK'
        end
      end
    end
  end
end
