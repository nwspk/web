Fabricator(:plan) do
  name       { "#{Faker::Commerce.color}-#{Random.rand(2000)}" }
  value      { Random.rand(2000) }
end
