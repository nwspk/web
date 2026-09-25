require 'rails_helper'

RSpec.describe Plan, type: :model do
  let(:plan) { Fabricate(:plan, value: 1000) }

  describe '#money_value' do
    it 'returns an instance of Money' do
      expect(plan.money_value).to be_instance_of Money
    end
  end


  describe '#description' do
    it 'returns a string' do
      expect(plan.description).to be_a String
    end
  end
end
