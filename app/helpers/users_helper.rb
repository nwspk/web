module UsersHelper
  def signup_fee
    Money.new(SIGNUP_FEE, 'GBP').format
  end

  def base_plan_rate
    base_plan_rate_raw.format
  end

  def base_plan_rate_raw
    Plan.first.nil? ? Money.new(0, 'GBP') : Plan.first.money_value
  end
end
