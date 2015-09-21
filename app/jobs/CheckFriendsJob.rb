class CheckFriendsJob
  def self.perform(user_id)
    u = User.find(user_id)

    s = CheckFriendsService.new
    s.call(u)
  end
end
