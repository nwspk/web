module HomeHelper
  def profile_image_url(user)
    return gravatar_url(user.email) if user.twitter.nil?

    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['TWITTER_KEY']
      config.consumer_secret     = ENV['TWITTER_SECRET']
      config.access_token        = user.twitter.access_token
      config.access_token_secret = user.twitter.secret
    end

    client.user.profile_image_uri_https(:original)
  end

  def gravatar_url(email)
    ["http://gravatar.com/avatar/", Digest::MD5.hexdigest(email)].join
  end
end
