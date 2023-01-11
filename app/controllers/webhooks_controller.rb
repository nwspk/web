class WebhooksController < ApplicationController
  protect_from_forgery :except => :index

  def index
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    event = nil

    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, STRIPE_WEBHOOK_SECRET
      )
    rescue JSON::ParserError => e
      # Invalid payload
      head :bad_request
      return
    rescue Stripe::SignatureVerificationError => e
      # Invalid signature
      head :bad_request
      return
    end

    case event.type
    when 'invoice.payment_succeeded'
      subscription = Subscription.find_by!(customer_id: event.data.object.id)
      on_invoice_paid(subscription, event.data.object)
    when 'invoice.payment_failed'
      subscription = Subscription.find_by!(customer_id: event.data.object.id)
      on_invoice_failed(subscription, event.data.object)
    end

    render json: { message: 'success' }
  end

  private

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
