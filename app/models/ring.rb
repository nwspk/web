class Ring < ActiveRecord::Base
  belongs_to :user
  has_many :door_accesses, dependent: :destroy

  def eligible_for_entry?
    self.user.admin? || (!self.user.subscription.nil? && (self.user.subscription.active? || self.user.subscription.grace_period?))
  end

  def record_entry!
    self.door_accesses.build(user: self.user).save!
  end
end
