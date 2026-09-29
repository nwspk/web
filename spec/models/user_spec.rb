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
