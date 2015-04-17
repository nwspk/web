class Plan < ActiveRecord::Base
  has_many :subscriptions

  validates :name, :stripe_id, :value, presence: true

  def description
    "#{self.name} - £#{self.value / 100} / month"
  end
end
