class Ring < ActiveRecord::Base
  belongs_to :user

  def eligible_for_entry?
    return false if self.user.subscription.nil?
    self.user.subscription.active? || self.user.subscription.grace_period?
  end
end
