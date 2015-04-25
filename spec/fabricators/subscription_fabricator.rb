Fabricator(:subscription) do
  user
  customer_id     "some_customer"
  subscription_id "some_subscription"
  plan_id         1
  active_until    nil
end
