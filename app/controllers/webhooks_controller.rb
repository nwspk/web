class WebhooksController < ApplicationController
  protect_from_forgery :except => :index

  def index
    raw_json = request.body.read

    unless raw_json.blank?
      event_json   = JSON.parse(raw_json)
      event        = Stripe::Event.retrieve(event_json['id'])

      case event.type
      when 'invoice.created'
        # subscription = Subscription.find_by!(customer_id: event.data.object.customer)
        # on_invoice_created(subscription, event.data.object) unless event.data.object.closed
      when 'invoice.payment_succeeded'
        subscription = Subscription.find_by!(customer_id: event.data.object.customer)
        on_invoice_paid(subscription, event.data.object)
      when 'invoice.payment_failed'
        subscription = Subscription.find_by!(customer_id: event.data.object.customer)
        on_invoice_failed(subscription, event.data.object)
      end
    end

    render nothing: true, status: 200
  rescue Stripe::InvalidRequestError
    render nothing: true, status: 200
  end

  private

  def on_invoice_created(subscription, invoice)
    items = Stripe::Invoice.retrieve(invoice.id).lines.all()
    return if items.data.size > 1

    discount_service = AddDiscountService.new
    discount_service.call(invoice, subscription, subscription.user)
  end

  def on_invoice_paid(subscription, invoice)
    subscription.update!(active_until: 30.days.from_now)
    Payment.create!(user: subscription.user, stripe_invoice_id: invoice.id, total: [invoice.total, 0].max, date: invoice.date, plan: subscription.plan)
    UserMailer.billing_email(subscription.user).deliver_later
  end

  def on_invoice_failed(subscription, _invoice)
    subscription.update!(active_until: nil)

    AdminMailer.payment_failed_email(subscription.user).deliver_later
    UserMailer.payment_failed_email(subscription.user).deliver_later
  end
end
