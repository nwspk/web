module SubscriptionsHelper
  def stripe_button(name, description, email, amount, label)
    content_tag :script, '', src: 'https://checkout.stripe.com/checkout.js', class: 'stripe-button', data: {
      key: STRIPE_PUBLIC_KEY,
      name: name,
      currency: 'gbp',
      description: description,
      email: email,
      amount: amount,
      'panel-label': label
    }
  end
end
