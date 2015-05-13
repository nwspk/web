class FetchConnectionUsernamesService
  def call
    facebook
    twitter
  end

  private

  def facebook
    connections = Connection.where(username: '', provider: 'facebook')
    graph       = Koala::Facebook::API.new(connections.first.access_token)

    graph.get_objects(connections.pluck(:uid)).each_pair do |uid, fb_user|
      Connection.find_by(provider: 'facebook', uid: uid).update(username: fb_user['name'])
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

    client.users(c.pluck(:uid)).each do |twitter_user|
      Connection.find_by(provider: 'twitter', uid: twitter_user.id).update(username: twitter_user.name)
    end
  end
end
