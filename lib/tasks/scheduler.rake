desc "This task is called by the Heroku scheduler add-on"
task :refresh_friends => :environment do
  puts "Refreshing friends..."

  users   = User.where(id: Connection.pluck(:user_id))
  backlog = users.to_a

  while backlog.size > 0
    u = backlog.pop

    begin
      service = CheckFriendsService.new
      service.call(u)
    rescue Twitter::Error::TooManyRequests => e
      backlog << u
    end
  end

  puts "Done."
end
