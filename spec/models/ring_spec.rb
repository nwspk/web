require 'rails_helper'

RSpec.describe Ring, type: :model do
  describe '#eligible_for_entry?' do
    it 'returns false for users without a subscription' do
      ring = Fabricate(:ring, user: user_with_subscription(User::ROLES[:member], '', nil))
      expect(ring.eligible_for_entry?).to be false
    end

    it 'returns true for users who ever had a subscription (grace period)' do
      ring = Fabricate(:ring, user: user_with_subscription(User::ROLES[:member], 'foo', 30.days.ago))
      expect(ring.eligible_for_entry?).to be true
    end

    it 'returns true for users with an active subscription' do
      ring = Fabricate(:ring, user: user_with_subscription(User::ROLES[:member], 'foo', 30.days.from_now))
      expect(ring.eligible_for_entry?).to be true
    end

    it 'returns true for admins' do
      ring = Fabricate(:ring, user: user_with_subscription(User::ROLES[:admin], '', nil))
      expect(ring.eligible_for_entry?).to be true
    end
  end

  def user_with_subscription(role, subscription_id, active_until)
    user = Fabricate(:user, role: role)
    Fabricate(:subscription, subscription_id: subscription_id, active_until: active_until, user: user)
    user
  end
end
