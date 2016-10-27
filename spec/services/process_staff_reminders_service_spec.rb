require 'rails_helper'

RSpec.describe ProcessStaffRemindersService, type: :model do
  let(:time) { Time.now }

  it 'sends out e-mails' do
    user     = Fabricate(:user)
    reminder = StaffReminder.create!(email: 'foo@bar', frequency: 6, last_run_at: time - 7.hours, active: true)

    s = ProcessStaffRemindersService.new
    s.call

    expect(ActionMailer::Base.deliveries).to_not be_empty

    email = ActionMailer::Base.deliveries.last

    expect(email.to).to eql [reminder.email]
    expect(email.subject).to eql "Member reminder: #{user.name}"
  end
end
