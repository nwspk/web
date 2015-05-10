class GraphsController < ApplicationController
  before_filter :authenticate_user!, only: :friends

  def full
    @graph = UserGraph::FullBuilder.new(user: current_user).build
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
    return nil if params[:start].nil?
    Date.civil(params[:start][:year].to_i, params[:start][:month].to_i, params[:start][:day].to_i)
  end

  def end_date
    return nil if params[:end].nil?
    Date.civil(params[:end][:year].to_i, params[:end][:month].to_i, params[:end][:day].to_i)
  end
end
