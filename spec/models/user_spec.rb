require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'callbacks' do
    it 'terminates a user\'s subscription upon deletion' do
      user = Fabricate(:user)
      Fabricate(:subscription, user: user)

      expect_any_instance_of(TerminateSubscriptionService).to receive(:call).with(kind_of(Subscription))

      user.destroy
    end
  end

  describe 'deleting a user who has acted as admissions staff' do
    let(:user) { admissions_staff }

    before do
      Fabricate(:subscription, user: user)
      staff_changes(user).add_note!(create_applicant, body: 'Seen at an event')
    end

    it 'is refused before anything else happens, so Stripe is left alone' do
      expect_any_instance_of(TerminateSubscriptionService).not_to receive(:call)

      expect(user.destroy).to be false
      expect(user.errors[:base]).to eq ['has acted as admissions staff; remove their admissions role instead']
      expect(User.where(id: user.id)).to exist
      expect(user.subscription.reload).to be_present
    end

    it 'still lets a user who never acted be deleted' do
      other = admissions_staff
      expect(other.destroy).to be_truthy
    end
  end

  describe 'sign-in tracking' do
    let(:user) { Fabricate(:user) }
    let(:request) { ActionDispatch::TestRequest.create('REMOTE_ADDR' => '203.0.113.9') }

    it 'records the sign-in count and times' do
      user.update_tracked_fields!(request)
      user.update_tracked_fields!(request)

      user.reload
      expect(user.sign_in_count).to eq 2
      expect(user.current_sign_in_at).to be_present
      expect(user.last_sign_in_at).to be_present
    end

    it 'keeps no IP addresses' do
      expect(User.column_names).not_to include('current_sign_in_ip', 'last_sign_in_ip')
    end
  end
end
