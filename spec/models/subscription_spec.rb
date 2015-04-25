require 'rails_helper'

RSpec.describe Subscription, type: :model do
  describe '#active?' do
    before do
      Timecop.freeze(Time.local(2015, 4, 23, 0, 46, 0))
    end

    let(:subscription) { Fabricate(:subscription) }

    it 'returns false when no active_until is set' do
      expect(subscription.active?).to be false
    end

    it 'returns true when active_until is set in the future' do
      subscription.active_until = 30.days.from_now
      expect(subscription.active?).to be true
    end

    it 'returns false when active_until is in the past' do
      subscription.active_until = Time.now - 1000
      expect(subscription.active?).to be false
    end

    it 'returns false when there is no Stripe subscription at all' do
      subscription.subscription_id = ''
      expect(subscription.active?).to be false
    end
  end
end
