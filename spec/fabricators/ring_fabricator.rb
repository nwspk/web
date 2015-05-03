Fabricator(:ring) do
  user
  uid { Faker::Code.ean }
end
