class ChangeCardService
  def call(customer_id, stripe_token)
    customer = Stripe::Customer.retrieve(customer_id)

    new_card = customer.sources.create(source: stripe_token)
    new_card.save

    customer.default_source = new_card.id
    customer.save
  end
end
