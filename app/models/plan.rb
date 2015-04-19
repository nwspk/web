class Plan < ActiveRecord::Base
  has_many :subscriptions

  validates :name, :stripe_id, :value, presence: true

  def description
    "#{self.name} - #{Money.new(self.value, 'GBP').format} / month"
  end
end
