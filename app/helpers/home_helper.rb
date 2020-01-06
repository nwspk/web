require 'open-uri'

module HomeHelper
  def profile_image_url(user)
    user.avatar.file.nil? ? gravatar_url(user.email) : user.avatar_url
  end

  def gravatar_url(email)
    ["https://gravatar.com/avatar/", Digest::MD5.hexdigest(email), "?s=250&d=", URI::encode(asset_url('default-face.jpg'))].join
  end

  def social_media_url(user)
    if !user.twitter.nil?
      user.twitter.profile_url
    elsif !user.facebook.nil?
      user.facebook.profile_url
    else
      graphs_full_url(focus: user.id)
    end
  end

  def goal_percent(pledge)
    ((pledge / (500 * base_plan_rate_raw)) * 100).round(1)
  end
end
