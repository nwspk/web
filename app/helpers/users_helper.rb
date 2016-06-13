module UsersHelper
  def signup_fee
    Money.new(SIGNUP_FEE, 'GBP').format
  end

  def base_plan_rate
    Plan.first.nil? ? Money.new(0, 'GBP').format : Plan.first.value.format
  end
end
