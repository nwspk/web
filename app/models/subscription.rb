class Subscription < ActiveRecord::Base
  belongs_to :user
  belongs_to :plan

  def active?
    !self.subscription_id.blank?
  end
end
