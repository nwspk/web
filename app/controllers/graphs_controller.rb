class GraphsController < ApplicationController
  before_filter :authenticate_user!, only: :friends
  before_action :parse_graph_options
  respond_to :html, :json, :gdf

  def full
    # Build graph
    builder     = UserGraph::FullBuilder.new(user: @focus, start: @start_date, end: @end_date, blacklist: @blacklist, no_staff: (params[:no_staff] != 'false'))
    @graph      = builder.build

    # Detect communities
    # service     = DetectCommunitiesService.new
    # service.call(@graph)

    respond_with @graph
  end

  def strangers
    builder = UserGraph::StrangersBuilder.new(user: current_user)
    @graph  = builder.build

    respond_with @graph
  end

  def friends
    builder = UserGraph::FriendsBuilder.new(user: current_user)
    @graph  = builder.build
    @show_all_nodes = true

    respond_with @graph
  end

  def access
    builder     = UserGraph::AccessBuilder.new(user: @focus, start: @start_date, end: @end_date)
    @graph      = builder.build
    @show_all_nodes = true

    respond_with @graph
  end

  private

  def parse_graph_options
    @small_logo     = true
    @show_all_nodes = true

    parse_date_range
    parse_focus
    parse_blacklist
  end

  def parse_date_range
    @date_range = params[:date_range] || 'all'

    case @date_range
    when 'day'
      @start_date = 1.day.ago
      @end_date   = Time.now
    when 'week'
      @start_date = 1.week.ago
      @end_date   = Time.now
    when 'month'
      @start_date = 1.month.ago
      @end_date   = Time.now
    else
      @start_date     = false
      @end_date       = false
      @show_all_nodes = false
    end
  end

  def parse_focus
    @focus = nil

    if params[:focus]
      begin
        @focus = User.find(params[:focus].to_i)
      rescue ActiveRecord::RecordNotFound
      end
    else
      @focus = current_user
    end
  end

  def parse_blacklist
    @blacklist = params[:exclude].is_a?(Array) ? params[:exclude].map { |x| x.to_i } : [params[:exclude].to_i]

    if @blacklist == [0]
      @blacklist = []
    end
  end
end
