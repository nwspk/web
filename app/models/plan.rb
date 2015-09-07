class Plan < ActiveRecord::Base
  has_many :subscriptions, dependent: :restrict_with_exception

  validates :name, :value, presence: true
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

  scope :visible, -> { where(visible: true) }

  before_create  :create_stripe_counterpart
  before_destroy :destroy_stripe_counterpart

  private

  def create_stripe_counterpart
    stripe_id = self.name.to_s.parameterize

    Stripe::Plan.create(
      amount: value.cents,
      name: self.name,
      id: stripe_id,
      interval: 'month',
      currency: value.currency.iso_code
    )

    self.stripe_id = stripe_id
  end

  def destroy_stripe_counterpart
    Stripe::Plan.retrieve(self.stripe_id).delete
  end
end
