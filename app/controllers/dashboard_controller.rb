class DashboardController < ApplicationController
  layout 'subpage'
  before_filter :authenticate_user!

  def index
  end
end
