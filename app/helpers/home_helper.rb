require 'open-uri'

module HomeHelper
  def profile_image_url(user)
    user.avatar.file.nil? ? default_avatar : user.avatar_url
  end

  def default_avatar
    ActionController::Base.helpers.asset_url('default-face.jpg', type: :image)
  end

  def social_media_url(user)
    if !user.twitter.nil?
      user.twitter.profile_url
    elsif !user.facebook.nil?
      user.facebook.profile_url
    else
      ''
    end
  end
end
