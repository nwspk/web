Fabricator(:subscription) do
  user
  plan
  customer_id     "some_customer"
  subscription_id "some_subscription"
  active_until    nil
end
