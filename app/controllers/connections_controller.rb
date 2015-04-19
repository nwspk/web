class ConnectionsController < ApplicationController
  before_filter :authenticate_user!

  def create
    auth = request.env['omniauth.auth']
    connection = Connection.find_or_create_by(provider: auth['provider'], uid: auth['uid'])

    connection.access_token = auth['credentials']['token']
    connection.secret       = auth['credentials']['secret']
    connection.expires_at   = auth['credentials']['expires_at']
    connection.user         = current_user
    connection.save!

    redirect_to dashboard_path, notice: 'Successfully connected account'
  end

  def failure
    redirect_to dashboard_path, alert: 'There was a problem authenticating you'
  end

  def index
    _friends = current_user.friends.to_a
    friends  = [].concat(_friends)

    _friends.each do |edge|
      friends = friends.concat(edge.to.friends.to_a)
    end

    @nodes = friends.map { |x| [x.from, x.to] }.flatten.uniq.map { |x| { id: x.id, name: x.name } }
    @edges = friends.map { |x| { source: x.from.id, target: x.to.id } }
  end

  def check_friends
    service = CheckFriendsService.new
    service.call(current_user)

    redirect_to dashboard_path, notice: 'Checked your friends, here are the results'
  rescue Twitter::Error::TooManyRequests => e
    redirect_to dashboard_path, alert: 'Failed to check friends, Twitter access is currently rate limited'
  end

  private

  def build_graph(depth = 0)
  end
end
