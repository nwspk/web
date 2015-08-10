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
    rescue Koala::Facebook::AuthenticationError => e
      puts "Could not authenticate with facebook for #{u.name}: #{e}"
    end
  end

  puts "Done."
end
