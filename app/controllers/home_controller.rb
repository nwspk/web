class HomeController < ApplicationController
  def index
    @graph = UserGraph::FullBuilder.new.build
  end

  def fellowship
  end

  def contact
  end
end
