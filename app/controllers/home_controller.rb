class HomeController < ApplicationController
  def index
    @graph = UserGraph::FullBuilder.new(user: current_user).build
  end

  def fellowship
  end

  def contact
  end

  def calendar
    redirect_to "https://hackpad.com/Newspeak-House-Events-Calendar-uNKMeHocJE9"
  end
end
