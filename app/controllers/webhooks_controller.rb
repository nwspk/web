class WebhooksController < ApplicationController
  protect_from_forgery :except => :index

  def index
    raw_json = request.body.read

    unless raw_json.blank?
      event_json   = JSON.parse(raw_json)
      event        = Stripe::Event.retrieve(event_json['id'])
      subscription = Subscription.find_by!(customer_id: event.data.object.customer)

      case event.type
      when 'invoice.created'
        on_invoice_created(subscription, event.data.object)
      when 'invoice.payment_succeeded'
        on_invoice_paid(subscription, event.data.object)
      end
    end

    render nothing: true, status: 200
  rescue Stripe::InvalidRequestError => e
    render nothing: true, status: 400
  end

  private

  def on_invoice_created(subscription, invoice)
    friends_service = CheckFriendsService.new
    friends_service.call(subscription.user)

    discount_service = AddDiscountService.new
    discount_service.call(invoice, subscription, subscription.user.friends)
  end

  def on_invoice_paid(subscription, invoice)
    subscription.update!(active_until: 30.days.from_now)
    Payment.create!(user: subscription.user, stripe_invoice_id: invoice.id, total: invoice.total, date: invoice.date)
  end
end
