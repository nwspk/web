require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'callbacks' do
    it 'sets the default role on a user on creation' do
      user = Fabricate(:user)
      expect(user.role).to eq User::ROLES[:member]
    end

    it 'terminates a user\'s subscription upon deletion' do
      user = Fabricate(:user)
      subscription = Fabricate(:subscription, user: user)

      any_instance_of(TerminateSubscriptionService) do |klass|
        stub(klass).call(is_a(Subscription))
      end

      user.destroy
    end
  end

  describe '#discount' do
    let(:user) { Fabricate(:user) }

    before do
      5.times { |i| FriendEdge.create(from: user, to_id: i, network: 'foo') }
    end

    it 'returns an instance of Money' do
      expect(user.discount).to be_instance_of Money
    end

    it 'returns the discount value based on number of friends' do
      expect(user.discount.cents).to eq 500
    end
  end
end
