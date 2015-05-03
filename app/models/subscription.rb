class Subscription < ActiveRecord::Base
  belongs_to :user
  belongs_to :plan

  validates :plan_id, presence: true, on: :create

  def active?
    !self.subscription_id.blank? && !self.active_until.nil? && self.active_until > Time.now
  end

  def grace_period?
    !self.active_until.nil? && self.active_until < Time.now
  end
end
