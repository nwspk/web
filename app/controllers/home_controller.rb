class HomeController < ApplicationController
  def index
    @graph = UserGraph::FullBuilder.new(user: current_user).build
  end

  def fellowship
  end

  def contact
  end
end
