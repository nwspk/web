class WebhooksController < ApplicationController
  protect_from_forgery :except => :index

  def index
    raw_json     = request.body.read

    unless raw_json.blank?
      event_json   = JSON.parse(raw_json)
      event        = Stripe::Event.retrieve(event_json['id'])
      subscription = Subscription.find_by!(customer_id: event.data.object.customer)

      case event.type
      when 'invoice.created'
        friends_service = CheckFriendsService.new
        friends_service.call(subscription.user)

        discount_service = AddDiscountService.new
        discount_service.call(event.data.object, subscription, subscription.user.friends)
      when 'invoice.payment_succeeded'
        subscription.update!(active_until: 30.days.from_now)
      end
    end

    render nothing: true, status: 200
  rescue Stripe::InvalidRequestError => e
    render nothing: true, status: 400
  end
end
