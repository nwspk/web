class Subscription < ActiveRecord::Base
  belongs_to :user
  belongs_to :plan

  validates :plan_id, presence: true

  def active?
    !self.subscription_id.blank?
  end
end
