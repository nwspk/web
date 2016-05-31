require 'rails_helper'

RSpec.describe Plan, type: :model do
  let(:plan) { Fabricate(:plan, value: 1000) }

  describe '#value' do
    it 'returns an instance of Money' do
      expect(plan.value).to be_instance_of Money
    end
  end

  describe '#value_with_discount' do
    let(:user) { Fabricate(:user) }

    before do
      5.times { |i| FriendEdge.create(from: user, to_id: i, network: 'foo') }
    end

    it 'returns an instance of Money' do
      expect(plan.value_with_discount(user)).to be_instance_of Money
    end

    it 'returns the plan value minus user discount' do
      expect(plan.value_with_discount(user).cents).to eq(plan.value.cents - (Money.new(500, 'GBP')/12).cents)
    end

    it 'does not return a value less than 0' do
      plan.update(value: 30)
      expect(plan.value_with_discount(user).cents).to eq 0
    end
  end

  describe '#description' do
    it 'returns a string' do
      expect(plan.description).to be_a String
    end
  end
end
