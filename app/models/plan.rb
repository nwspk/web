class Plan < ActiveRecord::Base
  has_many :subscriptions, dependent: :restrict_with_exception
  has_many :payments

  validates :name, :value, :stripe_id, presence: true
  validates :contribution, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  def description
    "#{self.name} - #{(value * 12).format} / yr"
  end

  def value
    Money.new(read_attribute(:value), 'GBP')
  end

  def value_with_discount(user)
    self.value - [user.discount / 12, self.value].min
  end

  scope :visible,     -> { where(visible: true).order('id asc').offset(1) }
  scope :all_visible, -> { where(visible: true).order('id asc') }
end
