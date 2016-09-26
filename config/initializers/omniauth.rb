Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET'], x_auth_access_type: 'read'
  provider :facebook, ENV['FACEBOOK_KEY'], ENV['FACEBOOK_SECRET'], scope: 'user_friends', display: 'page', info_fields: 'name,link'

  on_failure { |env| ConnectionsController.action(:failure).call(env) }
end
