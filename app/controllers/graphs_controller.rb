class GraphsController < ApplicationController
  before_filter :authenticate_user!, only: :friends

  def full
    @graph = UserGraph::FullBuilder.new.build
  end

  def friends
    builder = UserGraph::FriendsBuilder.new(user: current_user)
    @graph  = builder.build
  end

  def access
    builder = UserGraph::AccessBuilder.new(start: params[:start], end: params[:end])
    @graph  = builder.build
  end
end
