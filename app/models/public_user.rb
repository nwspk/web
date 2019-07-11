class PublicUser < User
  validates :url, absence: true

  # Do not confuse #applicant with User#applicant? - the latter is
  # a permanent attribute, while this is a transient attribute
  # that only decides whether to redirect the new user to checkout
  # Default role is "applicant" until checkout is complete anyway,
  # so no need to persist that
  attr_accessor :sponsor, :applicant

  before_validation :set_subscription_options

  private

  def set_subscription_options
    # Default to "basic" plan (first plan created)
    # But don't bother creating a subscription for an applicant
    self.build_subscription(plan_id: sponsor.blank? ? Plan.all_visible.first.try(:id) : sponsor) unless applicant == "1"
  end
end
