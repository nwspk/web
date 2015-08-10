class CheckFriendsService
  def call(user)
    if user.facebook
      check_facebook_friends(user)
    end

    if user.twitter
      check_twitter_friends(user)
    end
  end

  def check_facebook_friends(user)
    graph = Koala::Facebook::API.new(user.facebook.access_token)

    friends = graph.get_connections('me', 'friends')
    friend_ids = friends.map { |f| f['id'] }

    return if friend_ids.empty?

    users = Connection.where(provider: 'facebook', uid: friend_ids).includes(:user).map { |c| c.user }

    users.each do |friend|
      next if friend.nil?
      FriendEdge.find_or_create_by(from: user, to: friend, network: 'facebook')
      FriendEdge.find_or_create_by(from: friend, to: user, network: 'facebook')
    end
  end

  def check_twitter_friends(user)
    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['TWITTER_KEY']
      config.consumer_secret     = ENV['TWITTER_SECRET']
      config.access_token        = user.twitter.access_token
      config.access_token_secret = user.twitter.secret
    end

    begin
      friend_ids = client.friend_ids.to_a
    rescue Twitter::Error::TooManyRequests => e
      sleep e.rate_limit.reset_in + 1
      retry
    end

    return if friend_ids.empty?

    friend_profiles = []

    friend_ids.each_slice(100) do |batch|
      begin
        friend_profiles.concat client.friendships(batch)
      rescue Twitter::Error::TooManyRequests => e
        sleep e.rate_limit.reset_in + 1
        retry
      end
    end

    friend_ids = friend_profiles.select { |friend| friend.connections.include?('followed_by') }.map { |f| f.id }
    users = Connection.where(provider: 'twitter', uid: friend_ids).includes(:user).map { |c| c.user }

    users.each do |friend|
      next if friend.nil?
      FriendEdge.find_or_create_by(from: user, to: friend, network: 'twitter')
      FriendEdge.find_or_create_by(from: friend, to: user, network: 'twitter')
    end
  end
end
