class Subscription < ActiveRecord::Base
  belongs_to :user
  belongs_to :plan

  validates :plan_id, presence: true, on: :create

  scope :with_credit_card, -> { where.not(customer_id: '') }
  scope :active, -> { where.not(subscription_id: '', active_until: nil) }

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

  after_save :set_user_role

  private

  def set_user_role
    if active? && self.user.applicant?
      self.user.update(role: User::ROLES[:member])
    end
  end
end
