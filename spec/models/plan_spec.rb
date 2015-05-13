require 'rails_helper'

RSpec.describe Plan, type: :model do
  let(:plan) { Fabricate(:plan) }

  describe '#value' do
    it 'returns an instance of Money' do
      expect(plan.value).to be_instance_of Money
    end
  end

  describe '#value_with_discounts' do
    pending
  end

  describe '#description' do
    it 'returns a string' do
      expect(plan.description).to be_a String
    end
  end

  describe 'callbacks' do
    it 'creates a Stripe plan' do
      mock(Stripe::Plan).create(is_a(Hash))
      Fabricate(:plan)
    end

    it 'deletes a Stripe plan' do
      any_instance_of(Stripe::Plan) do |klass|
        mock(klass).delete
      end

      plan.destroy
    end
  end
end
