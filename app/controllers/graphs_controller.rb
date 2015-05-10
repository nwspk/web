class GraphsController < ApplicationController
  before_filter :authenticate_user!, only: :friends

  def full
    @start_date = start_date
    @end_date   = end_date
    builder     = UserGraph::FullBuilder.new(user: current_user, start: @start_date, end: @end_date)
    @graph      = builder.build
  end

  def friends
    builder = UserGraph::FriendsBuilder.new(user: current_user)
    @graph  = builder.build
  end

  def access
    @start_date = start_date || 1.day.ago
    @end_date   = end_date   || 1.day.from_now
    builder     = UserGraph::AccessBuilder.new(user: current_user, start: @start_date, end: @end_date)
    @graph      = builder.build
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
