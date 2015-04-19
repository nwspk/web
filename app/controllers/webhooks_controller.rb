class WebhooksController < ApplicationController
  protect_from_forgery :except => :index

  def index
    event_json   = JSON.parse(request.body.read)
    event        = Stripe::Event.retrieve(event_json['id'])
    subscription = Subscription.find(customer_id: event.data.object.customer)

    case event.type
    when 'invoice.created'
      # todo
    when 'invoice.payment_succeeded'
      subscription.update!(active_until: 30.days.from_now)
    end

    render nothing: true, status: 200
  end
end
