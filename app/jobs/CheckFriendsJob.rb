class CheckFriendsJob
  @queue = :long

  def self.perform(user_id)
    u = User.find(user_id)
    flush "Starting CheckFriendsService for User #{u.name} <#{u.email}>"

    s = CheckFriendsService.new
    s.call(u)

    flush "CheckFriendsService completed"
  end

  private

  def flush(str)
    puts str
    $stdout.flush
  end
end
