require 'rails_helper'

RSpec.describe Admissions::ApplicantEvent do
  let(:applicant) { create_applicant }
  let(:event) { applicant.events.first }

  describe 'append-only' do
    it 'refuses updates' do
      expect { event.update!(kind: 'moved') }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { event.update_column(:kind, 'moved') }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { event.update_columns(body: 'x') }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { event.touch }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect(event.reload.kind).to eq 'created'
    end

    it 'refuses deletes' do
      expect { event.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { event.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { event.delete }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect(described_class.where(id: event.id)).to exist
    end

    it 'refuses changes to rows loaded fresh from the database' do
      fresh = described_class.find(event.id)
      fresh.body = 'rewritten'
      expect { fresh.save }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'keeps the applicant from being deleted' do
      expect { applicant.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'refuses writes that bypass the model, at the database' do
      rows = described_class.where(id: event.id)
      expect_refused { rows.update_all(kind: 'moved') }
      expect_refused { rows.update_all(body: 'rewritten') }
      expect_refused { rows.update_all(body: nil) } # blanking must be stamped
      expect_refused { rows.delete_all }
      expect_refused { described_class.connection.execute('TRUNCATE admissions_applicant_events CASCADE') }
      expect_refused(ActiveRecord::ReadOnlyRecord) { event.save(validate: false) }
      expect(rows.first.attributes).to eq event.attributes
    end

    it 'allows only the redaction: blanking a body with a stamp' do
      staff_changes.add_note!(applicant, body: 'Spoke on the phone')
      note = applicant.events.last
      at = Time.current.floor(6)
      described_class.redact_bodies_for(applicant, at: at)
      expect(note.reload).to have_attributes(body: nil, redacted_at: at, kind: 'note_added')
      expect_refused { described_class.where(id: note.id).update_all(body: nil, redacted_at: at, kind: 'moved') }
    end
  end

  describe 'attribution' do
    def build(**attrs)
      described_class.new(applicant: applicant, kind: 'note_added', created_at: Time.current, **attrs)
    end

    it 'requires a user for a staff actor and none otherwise' do
      user = admissions_staff
      expect(build(actor_type: 'staff')).not_to be_valid
      expect(build(actor_type: 'staff', actor_user: user)).to be_valid
      expect(build(actor_type: 'applicant', actor_user: user)).not_to be_valid
      expect(build(actor_type: 'system')).to be_valid
      expect(build(actor_type: 'ed')).not_to be_valid
    end

    it 'knows its kinds and stages' do
      expect(build(actor_type: 'system', kind: 'emailed')).not_to be_valid
      expect(build(actor_type: 'system', to_stage: 'interviewing')).not_to be_valid
    end

    it 'gives back the actor' do
      user = admissions_staff
      staff_changes(user).add_note!(applicant, body: 'x')
      expect(applicant.events.last.actor).to eq Admissions::Actor.staff(user)
    end
  end
end
