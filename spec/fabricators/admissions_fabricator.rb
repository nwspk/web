Fabricator(:admissions_round, from: 'Admissions::Round') do
  name { sequence(:admissions_round) { |i| "Fellowship #{2026 + i}" } }
  opens_on { Date.new(2026, 9, 1) }
  invites_on { Date.new(2027, 2, 1) }
  closes_on { Date.new(2027, 6, 30) }
end

Fabricator(:admissions_staff_member, from: 'Admissions::StaffMember') do
  user
  role 'lead'
end

# Applicants are built through Admissions::ApplicantChanges, never directly,
# so the log and the cached state agree; see spec/support/admissions.rb.
