require "rails_helper"

RSpec.describe AdminMailer, type: :mailer do
  before do
    @admin = Fabricate(:user, role: User::ROLES[:admin])
  end

  describe '#payment_failed_email' do
    skip # Tested in controllers/webhooks_controller_spec.rb
  end

  describe '#new_member_email' do
    it 'sends e-mail when a user is created' do
      user  = Fabricate(:user)
      email = ActionMailer::Base.deliveries.last

      expect(email.subject).to eql "New member signed up: #{user.name}"
      expect(email.to).to eql [@admin.email]
    end
  end

  describe '#new_subscriber_email' do
    pending
  end
end
