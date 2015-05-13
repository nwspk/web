class ConnectionsController < ApplicationController
  before_filter :authenticate_user!

  def create
    auth = request.env['omniauth.auth']
    connection = Connection.find_or_create_by(provider: auth['provider'], uid: auth['uid'])

    connection.access_token = auth['credentials']['token']
    connection.secret       = auth['credentials']['secret']
    connection.expires_at   = auth['credentials']['expires_at']
    connection.profile_url  = auth['info']['urls'][auth['provider'].capitalize]
    connection.username     = auth['info']['nickname']
    connection.user         = current_user
    connection.save!

    if current_user.subscription.try(:needs_checkout?)
      redirect_to subscription_checkout_path
    else
      redirect_to dashboard_path, notice: 'Successfully connected account'
    end
  end

  def destroy
    connection = Connection.find(params[:id])

    service = RemoveConnectionService.new
    service.call(connection)

    redirect_to dashboard_path, notice: 'Successfully disconnected account'
  end

  def failure
    redirect_to dashboard_path, alert: 'There was a problem authenticating you'
  end

  def check_friends
    service = CheckFriendsService.new
    service.call(current_user)

    redirect_to dashboard_path, notice: 'Checked your friends, here are the results'
  rescue Twitter::Error::TooManyRequests => e
    redirect_to dashboard_path, alert: 'Failed to check friends, Twitter access is currently rate limited'
  end
end
