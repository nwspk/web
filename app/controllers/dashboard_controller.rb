class DashboardController < ApplicationController
  layout 'subpage'
  before_action :authenticate_user!

  def index; end
end
