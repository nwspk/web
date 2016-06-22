class AddDiscountService
  def call(invoice, subscription, user)
    return if invoice.total == 0

    Stripe::InvoiceItem.create(
      customer: subscription.customer_id,
      invoice: invoice.id,
      amount: [(user.discount.cents / 12), subscription.plan.value].min * -1,
      currency: 'gbp',
      description: "Discount for friends"
    )
  end
end
