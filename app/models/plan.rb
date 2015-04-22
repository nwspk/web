class Plan < ActiveRecord::Base
  has_many :subscriptions, dependent: :restrict_with_exception

  validates :name, :value, presence: true

  def description
    "#{self.name} - #{Money.new(self.value, 'GBP').format} / month"
  end

  before_create  :create_stripe_counterpart
  before_destroy :destroy_stripe_counterpart

  private

  def create_stripe_counterpart
    stripe_id = self.name.to_s.parameterize

    Stripe::Plan.create(
      amount: self.value,
      name: self.name,
      id: stripe_id,
      interval: 'month',
      currency: 'gbp'
    )

    self.stripe_id = stripe_id
  end

  def destroy_stripe_counterpart
    Stripe::Plan.retrieve(self.stripe_id).delete
  end
end
