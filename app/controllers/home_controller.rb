class HomeController < ApplicationController
  def index
  	@graph = UserGraph.full
  end

  def build_graph(depth = 0)
  end

  def membership
  end

  def fellowship
  end

  def contact
  end
end
