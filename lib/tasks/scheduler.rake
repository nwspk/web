desc "Refresh friends for everyone"
task :refresh_friends => :environment do
  puts "Refreshing friends..."

  users   = User.where(id: Connection.pluck(:user_id))
  backlog = users.to_a

  while backlog.size > 0
    u = backlog.pop

    begin
      service = CheckFriendsService.new
      service.call(u)
    rescue Koala::Facebook::AuthenticationError => e
      puts "Could not authenticate with facebook for #{u.name}: #{e}"
    end
  end

  puts "Done."
end

desc "Check for due staff reminders and send them"
task :remind_staff => :environment do
  puts "Reminding staff..."

  s = ProcessStaffRemindersService.new
  s.call

  puts "Done."
end
