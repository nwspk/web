class AddDiscountService
  def call(invoice, subscription, friends)
    Stripe::InvoiceItem.create(
      customer: subscription.customer_id,
      invoice: invoice.id,
      amount: friends.count('distinct to_id') * 100 * -1,
      currency: 'gbp',
      description: "Discount for #{friends.count} friends"
    )
  end
end
