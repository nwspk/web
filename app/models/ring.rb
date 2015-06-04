class Ring < ActiveRecord::Base
  belongs_to :user
  has_many :door_accesses, dependent: :destroy

  SIZES = (1..20).collect { |x| (0..9).map { |y| (x + (y * 0.1)).round(1) } }.flatten.take(191)

  def eligible_for_entry?
    self.user.admin? || self.user.staff? || (!self.user.subscription.nil? && (self.user.subscription.active? || self.user.subscription.grace_period?))
  end

  def record_entry!
    self.door_accesses.build(user: self.user).save!
  end
end
