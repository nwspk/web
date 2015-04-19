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
    graph   = Koala::Facebook::API.new(user.facebook.access_token)

    friends = graph.get_connections('me', 'friends')
    friend_ids = friends.map { |f| f['id'] }

    p friends
    p friend_ids

    return if friend_ids.empty?

    users = Connection.where(provider: 'facebook', uid: friend_ids).includes(:user)

    users.each do |friend|
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

    friend_ids = client.friend_ids.to_a

    return if friend_ids.empty?

    friend_profiles = []

    friend_ids.each_slice(100) do |batch|
      friend_profiles.concat client.friendships(batch)
    end

    friend_ids = friend_profiles.select { |friend| friend.connections.include?('followed_by') }

    p friend_ids

    users = Connection.where(provider: 'twitter', uid: friend_ids).includes(:user)

    users.each do |friend|
      FriendEdge.find_or_create_by(from: user, to: friend, network: 'twitter')
      FriendEdge.find_or_create_by(from: friend, to: user, network: 'twitter')
    end
  end
end
