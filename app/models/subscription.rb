class Subscription < ActiveRecord::Base
  belongs_to :user
  belongs_to :plan

  validates :plan_id, presence: true, on: :create

  scope :with_credit_card, -> { where.not(customer_id: '') }
  scope :active, -> { where.not(subscription_id: '', active_until: nil) }

  def active?
    subscription_id.present? && !active_until.nil? && active_until > Time.zone.now
  end

  def grace_period?
    !active_until.nil? && active_until < Time.zone.now
  end

  def needs_checkout?
    customer_id.blank?
  end

  def plan_name
    plan.try(:name)
  end

  after_save :set_user_role

  private

  def set_user_role
    return unless active? && user.applicant?

    user.update(role: User::ROLES[:member])
  end
end
