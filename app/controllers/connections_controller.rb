class ConnectionsController < ApplicationController
  before_filter :authenticate_user!

  def create
    auth = request.env['omniauth.auth']
    connection = Connection.find_or_create_by(provider: auth['provider'], uid: auth['uid'])

    connection.access_token = auth['credentials']['token']
    connection.secret       = auth['credentials']['secret']
    connection.expires_at   = auth['credentials']['expires_at']
    connection.profile_url  = auth['info']['urls'][auth['provider'].capitalize]
    connection.username     = auth['info']['nickname'] || auth['info']['name']
    connection.user         = current_user
    connection.save!

    # Immediately check for friends
    CheckFriendsWorker.perform_async(current_user.id)

    redirect_to redirect_path, notice: 'Successfully connected account'
  end

  def destroy
    connection = Connection.find(params[:id])

    service = RemoveConnectionService.new
    service.call(connection)

    redirect_to dashboard_path, notice: 'Successfully disconnected account'
  end

  def failure
    redirect_to redirect_path, alert: 'There was a problem authenticating you'
  end

  def check_friends
    if current_user.facebook && current_user.facebook.expired?
      redirect_to '/auth/facebook'
      return
    end

    if current_user.twitter && current_user.twitter.expired?
      redirect_to '/auth/twitter'
      return
    end

    CheckFriendsWorker.perform_async(current_user.id)
    redirect_to dashboard_path, notice: 'Checking your friends, this may take a while'
  end

  private

  def redirect_path
    if current_user.subscription.try(:needs_checkout?)
      checkout_subscription_path
    else
      dashboard_path
    end
  end
end
