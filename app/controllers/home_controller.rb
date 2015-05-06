class HomeController < ApplicationController
  def index
    @graph = UserGraph.full
  end

  def fellowship
  end

  def contact
  end
end
