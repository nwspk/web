class FetchConnectionUsernamesService
  def call
    facebook
    twitter
  end

  private

  def facebook
    connections = Connection.where(username: '', provider: 'facebook')

    return if connections.size < 1

    graph = Koala::Facebook::API.new(connections.first.access_token)

    graph.get_objects(connections.pluck(:uid)).each_pair do |uid, fb_user|
      c = Connection.find_by(provider: 'facebook', uid: uid)
      next if c.nil?
      c.update(username: fb_user['name'])
    end
  end

  def twitter
    connections = Connection.where(username: '', provider: 'twitter')

    return if connections.size < 1

    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['TWITTER_KEY']
      config.consumer_secret     = ENV['TWITTER_SECRET']
      config.access_token        = connections.first.access_token
      config.access_token_secret = connections.first.secret
    end

    client.users(connections.pluck(:uid)).each do |twitter_user|
      c = Connection.find_by(provider: 'twitter', uid: twitter_user.id)
      next if c.nil?
      c.update(username: twitter_user.name)
    end
  end
end
