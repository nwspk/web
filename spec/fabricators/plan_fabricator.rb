Fabricator(:plan) do
  name       { sequence(:plan) { |i| "Plan #{i}" } }
  value      { Random.rand(2000) }
  stripe_id  { sequence(:plan) { |i| "plan_#{i}" } }
end
