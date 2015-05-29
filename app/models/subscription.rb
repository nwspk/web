class Subscription < ActiveRecord::Base
  belongs_to :user
  belongs_to :plan

  validates :plan_id, presence: true, on: :create

  scope :with_credit_card, -> { where.not(customer_id: '') }

  def active?
    !self.subscription_id.blank? && !self.active_until.nil? && self.active_until > Time.now
  end

  def grace_period?
    !self.active_until.nil? && self.active_until < Time.now
  end

  def needs_checkout?
    self.customer_id.blank?
  end

  def plan_name
    self.plan.try(:name)
  end
end
