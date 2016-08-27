class CheckFriendsWorker
  include Sidekiq::Worker

  def perform(user_id)
    u = User.find(user_id)

    s = CheckFriendsService.new
    s.call(u)
  rescue Koala::Facebook::AuthenticationError, Twitter::Error::Unauthorized
    #
  end
end
