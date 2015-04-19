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

    p friend_ids

    users = Connection.where(provider: 'facebook', uid: friend_ids).includes(:user)

    users.each do |friend|
      FriendEdge.find_by_or_create(from: user, to: friend, network: 'facebook')
      FriendEdge.find_by_or_create(from: friend, to: user, network: 'facebook')
    end
  end

  def check_twitter_friends(user)
    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['TWITTER_KEY']
      config.consumer_secret     = ENV['TWITTER_SECRET']
      config.access_token        = user.twitter.access_token
      config.access_token_secret = user.twitter.secret
    end

    friend_ids = client.friend_ids(user.twitter.uid)
    friend_profiles = client.friendships(friend_ids)
    friend_ids = friend_profiles.select { |friend| friend.connections.include?('followed_by') }

    p friend_ids

    users = Connection.where(provider: 'twitter', uid: friend_ids).includes(:user)

    users.each do |friend|
      FriendEdge.find_by_or_create(from: user, to: friend, network: 'twitter')
      FriendEdge.find_by_or_create(from: friend, to: user, network: 'twitter')
    end
  end
end
