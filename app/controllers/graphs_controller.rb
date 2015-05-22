class GraphsController < ApplicationController
  before_filter :authenticate_user!, only: :friends
  respond_to :html, :json, :gdf

  def full
    @start_date = start_date
    @end_date   = end_date
    @blacklist  = params[:exclude].is_a?(Array) ? params[:exclude].map { |x| x.to_i } : [params[:exclude].to_i]

    # Build graph
    builder     = UserGraph::FullBuilder.new(user: current_user, start: @start_date, end: @end_date, blacklist: @blacklist)
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
