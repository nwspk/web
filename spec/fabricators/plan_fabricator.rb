Fabricator(:plan) do
  name       { Faker::Commerce.color }
  value      { Random.rand(2000) }
end
