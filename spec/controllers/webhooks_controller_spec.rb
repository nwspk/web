require 'rails_helper'

RSpec.describe WebhooksController, type: :controller do
  describe "POST #index" do
    it 'returns http success on an empty request' do
      post :index
      expect(response).to have_http_status(:success)
    end

    it 'return an error on a fake event request' do
      post :index, { id: 'fake' }.to_json
      expect(response).to have_http_status(:bad_request)
    end

    context "Functional tests" do
      before :all do
        StripeMock.start
      end

      after :all do
        StripeMock.stop
      end

      before :each do
        Timecop.freeze(Time.local(2015, 4, 23, 0, 46, 0))
      end

      let(:subscription) { Fabricate(:subscription, customer_id: "foo_000") }

      it 'updates local subscription on successful payment' do
        event = StripeMock.mock_webhook_event('invoice.payment_succeeded', {
          customer: subscription.customer_id
        })

        stub(Stripe::Event).retrieve { event }
        post :index, event.to_json

        expect(response).to have_http_status(:success)
        expect(subscription.reload.active_until).to eq 30.days.from_now
      end

      it 'adds friend discount when an invoice is generated' do
        pending
      end
    end
  end
end
