module AdmissionsHelpers
  def admissions_staff(role: 'lead', user: Fabricate(:user))
    Fabricate(:admissions_staff_member, user: user, role: role).user
  end

  def staff_changes(user = admissions_staff)
    Admissions::ApplicantChanges.new(Admissions::Actor.staff(user))
  end

  # Acting as the applicant whose record this is (nil: a new EOI).
  def applicant_changes(applicant = nil) = Admissions::ApplicantChanges.new(Admissions::Actor.applicant(applicant))
  def system_changes = Admissions::ApplicantChanges.new(Admissions::Actor.system)

  # A new applicant, created by hand by staff at `stage`.
  def create_applicant(stage: 'eoi', round: Fabricate(:admissions_round), by: staff_changes, **attrs)
    by.create!(round: round, email: Faker::Internet.email, phone: Faker::PhoneNumber.phone_number,
               name: Faker::Name.name, stage: stage, **attrs)
  end
end

RSpec.configure { |config| config.include AdmissionsHelpers }

module AdmissionsHelpers
  # An applicant sitting at any state: funnel stages are created there by
  # hand, on_hold is held from `applied`, exits are exited from `applied`.
  def applicant_at(state, round: Fabricate(:admissions_round))
    s = staff_changes
    if Admissions::Stages::FUNNEL.include?(state)
      create_applicant(stage: state, round: round)
    elsif state == Admissions::Stages::ON_HOLD
      create_applicant(stage: 'applied', round: round).tap do |a|
        s.hold!(a, until_date: Date.current + 14, reason: 'Waiting on another decision')
      end
    else
      create_applicant(stage: 'applied', round: round).tap { |a| s.exit!(a, to: state) }
    end
  end
end

module AdmissionsHelpers
  # Expects the block to be refused, inside a savepoint so a database error
  # doesn't poison the rest of the test's transaction.
  def expect_refused(error = ActiveRecord::StatementInvalid, message = nil, &block)
    ActiveRecord::Base.transaction(requires_new: true) do
      expect(&block).to raise_error(error, message)
      raise ActiveRecord::Rollback
    end
  end

  # Runs raw writes with the service's permission, as ApplicantChanges does:
  # for simulating tampering by someone who bypasses the service on purpose.
  def with_service_write
    ActiveRecord::Base.transaction(requires_new: true) do
      ActiveRecord::Base.connection.execute("SELECT set_config('admissions.service_write', 'on', true)")
      yield
      ActiveRecord::Base.connection.execute("SELECT set_config('admissions.service_write', 'off', true)")
    end
  end
end
