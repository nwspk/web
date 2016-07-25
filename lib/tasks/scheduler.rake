desc "Refresh friends for everyone"
task :refresh_friends => :environment do
  users = User.where(id: Connection.pluck(:user_id))

  Parallel.each(users.to_a, progress: 'Fetching connections', in_threads: 4) do |u|
    begin
      ActiveRecord::Base.connection_pool.with_connection do
        CheckFriendsService.new.call(u)
      end
    rescue Koala::Facebook::AuthenticationError, Twitter::Error::Unauthorized
      #
    end
  end
end

desc "Check for due staff reminders and send them"
task :remind_staff => :environment do
  puts "Reminding staff..."

  s = ProcessStaffRemindersService.new
  s.call

  puts "Done."
end
