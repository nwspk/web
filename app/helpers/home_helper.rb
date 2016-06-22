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
  rescue Twitter::Error
    return gravatar_url(user.email)
  end

  def gravatar_url(email)
    ["http://gravatar.com/avatar/", Digest::MD5.hexdigest(email), "?s=250"].join
  end

  def social_media_url(user)
    if !user.twitter.nil?
      return user.twitter.profile_url
    elsif !user.facebook.nil?
      return user.facebook.profile_url
    else
      return graphs_full_url(focus: user.id)
    end
  end

  def goal_percent(pledge)
    (pledge / (1000 * base_plan_rate_raw)) * 100
  end
end
