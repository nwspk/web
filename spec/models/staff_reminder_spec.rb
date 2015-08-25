require 'rails_helper'

RSpec.describe StaffReminder, type: :model do
  let(:users) { Fabricate.times(4, :user) }

  describe '#due?' do
    it 'returns true when reminder was last run more than frequency hours ago' do
      time     = Time.now
      reminder = StaffReminder.create(email: 'foo@bar', frequency: 6, last_run_at: time - 8.hours)

      expect(reminder.due?).to be true
    end

    it 'returns false when reminder was run recently enough' do
      time     = Time.now
      reminder = StaffReminder.create(email: 'foo@bar', frequency: 6, last_run_at: time - 5.hours)

      expect(reminder.due?).to be false
    end
  end

  describe '#pop!' do
    let(:reminder) { StaffReminder.create(email: 'foo@bar', frequency: 1, last_id: 0) }

    it 'skips over staff or admin users' do
      reminder.update(last_id: users[1].id)
      users[2].update(role: User::ROLES[:admin])

      new_user = reminder.pop!

      expect(new_user).to eql users[3]
    end

    it 'skips over non-existent users' do
      users[0].destroy

      new_user = reminder.pop!

      expect(new_user).to eql users[1]
    end

    it 'loops back onto the first user' do
      reminder.update(last_id: users[3].id)

      new_user = reminder.pop!

      expect(new_user).to eql users[0]
    end
  end
end
