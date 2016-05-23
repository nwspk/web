class HomeController < ApplicationController
  def index
    @events  = Event.public_and_confirmed.limit(3)
    @members = User.with_subscription.limit(3)
    @fellows = User.fellows.limit(8)
  end

  def fellowship
  end

  def contact
  end

  def calendar
    redirect_to "https://hackpad.com/Newspeak-House-Events-Calendar-uNKMeHocJE9"
  end
end
