require 'rails_helper'

RSpec.describe Payment, type: :model do
  describe '#total' do
    it 'returns an instance of Money' do
      payment = Payment.new(total: 100)
      expect(payment.total).to be_instance_of Money
    end
  end
end
