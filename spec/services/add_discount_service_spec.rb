require 'rails_helper'

RSpec.describe AddDiscountService, type: :model do
  let(:user) { Fabricate(:user) }
  let(:subscription) { Fabricate(:subscription, user: user) }
  let(:invoice) { h = { id: 1, total: 1 }; Struct.new(*h.keys).new(*h.values) }

  describe 'adds a discount' do
    it 'ignores invoices that were not going to charge anything anyway' do
      invoice.total = 0
      stub(Stripe::InvoiceItem).create(is_a(Hash)) { raise_error }
      expect { AddDiscountService.new.call(invoice, subscription, user) }.to_not raise_error
    end

    it 'equals the number of friends divided by 12' do
      5.times { |i| FriendEdge.create(from: user, to_id: i, network: 'foo') }

      discount = nil
      mock(Stripe::InvoiceItem).create(is_a(Hash)) { |h| discount = h }

      AddDiscountService.new.call(invoice, subscription, user)
      expect(discount[:amount]).to eq(5 * 100 / 12 * -1)
    end

    it 'cannot be greater than the plan value' do
      subscription.plan.update(value: 100)
      50.times { |i| FriendEdge.create(from: user, to_id: i, network: 'foo') }

      discount = nil
      mock(Stripe::InvoiceItem).create(is_a(Hash)) { |h| discount = h }

      AddDiscountService.new.call(invoice, subscription, user)
      expect(discount[:amount]).to eq(100 * -1)
    end
  end
end
