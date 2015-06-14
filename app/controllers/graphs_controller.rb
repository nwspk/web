class GraphsController < ApplicationController
  before_filter :authenticate_user!, only: :friends
  respond_to :html, :json, :gdf

  def full
    @small_logo = true
    @date_range = params[:date_range] || 'all'
    @blacklist  = params[:exclude].is_a?(Array) ? params[:exclude].map { |x| x.to_i } : [params[:exclude].to_i]

    if @blacklist == [0]
      @blacklist = [User.find_by(email: DEFAULT_USER_EXCLUDE).try(:id)]
    end

    case @date_range
    when 'day'
      _start_date = 1.day.ago
      _end_date   = Time.now
    when 'week'
      _start_date = 1.week.ago
      _end_date   = Time.now
    when 'month'
      _start_date = 1.month.ago
      _end_date   = Time.now
    else
      _start_date = false
      _end_date   = false
    end

    # Build graph
    builder     = UserGraph::FullBuilder.new(user: current_user, start: _start_date, end: _end_date, blacklist: @blacklist)
    @graph      = builder.build

    # Detect communities
    service     = DetectCommunitiesService.new
    service.call(@graph)

    respond_with @graph
  end

  def friends
    builder = UserGraph::FriendsBuilder.new(user: current_user)
    @graph  = builder.build

    respond_with @graph
  end

  def access
    @start_date = start_date || 1.day.ago
    @end_date   = end_date   || 1.day.from_now
    builder     = UserGraph::AccessBuilder.new(user: current_user, start: @start_date, end: @end_date)
    @graph      = builder.build

    respond_with @graph
  end

  private

  def start_date
    Date.civil(params[:start][:year].to_i, params[:start][:month].to_i, params[:start][:day].to_i)
  rescue
    false
  end

  def end_date
    Date.civil(params[:end][:year].to_i, params[:end][:month].to_i, params[:end][:day].to_i)
  rescue
    false
  end
end
