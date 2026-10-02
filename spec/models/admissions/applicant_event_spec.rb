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
      expect { applicant.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
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
