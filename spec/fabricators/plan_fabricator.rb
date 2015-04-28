Fabricator(:plan) do
  name       { Faker::Name.title }
  value      { Random.rand(2000) }
end
