require 'rails_helper'

RSpec.describe 'The EOI form at /admissions', type: :request do
  let(:lead) { admissions_staff }
  let!(:round) do
    Fabricate(:admissions_round, name: 'Fellowship 2027', opens_on: Date.current - 30, invites_on: Date.current + 60)
  end

  before do
    Admissions::FormText.create!(key: 'privacy_notice', created_by_user: lead,
                                 body: "Test privacy notice, paragraph one.\n\nParagraph two: https://example.com/policy.")
    Admissions::FormText.create!(key: 'eoi_introduction', created_by_user: lead,
                                 body: 'Test introduction <b>not bold</b>.')
    # An EOI has no name, so these use only {{round}}.
    email_template(round, 'confirmation', subject: 'Test confirmation', body: 'Test body for {{round}}.')
    email_template(round, 'holding', subject: 'Test holding', body: 'Test holding body.')
  end

  def post_eoi(email: 'new.person@example.com', phone: '', **extra)
    post '/admissions', params: { eoi: { email: email, phone: phone } }.merge(extra)
  end

  describe 'the form' do
    it 'shows the fields, the introduction and the privacy notice, in the site layout, to anyone' do
      get '/admissions'

      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)
      expect(page.at('aside')).to be_present # the site sidebar, not a staff screen
      expect(page.at('h2').text).to eq 'Register your interest'
      expect(page.at('.eoi-introduction').text.strip).to eq 'Test introduction <b>not bold</b>.'
      expect(page.at('.eoi-introduction b')).to be_nil
      expect(page.css('.eoi-privacy p').map(&:text))
        .to eq ['Test privacy notice, paragraph one.', 'Paragraph two: https://example.com/policy.']
      expect(page.at('.eoi-privacy a')['href']).to eq 'https://example.com/policy'
      fields = page.css('#eoi-form input').reject { |i| %w[hidden submit].include?(i['type']) }.map { |i| i['name'] }
      expect(fields).to eq %w[website eoi[email] eoi[phone]]
      expect(page.at('#eoi_email')['required']).to be_present
      expect(page.at('#eoi_phone')['required']).to be_nil
      expect(page.css('#eoi-form label[for]').map { |l| l['for'] }).to eq %w[website eoi_email eoi_phone]
    end

    it 'loads no third-party script' do
      get '/admissions'
      sources = Nokogiri::HTML(response.body).css('script[src]').map { |s| s['src'] }
      expect(sources).to all(start_with('/'))
    end

    it 'leaves out the introduction when there is none' do
      Admissions::FormText.create!(key: 'eoi_introduction', created_by_user: lead, body: '')
      get '/admissions'
      expect(Nokogiri::HTML(response.body).at('.eoi-introduction')).to be_nil
    end
  end

  describe 'a submission' do
    it 'saves the EOI and thanks the submitter' do
      post_eoi(phone: '07700 900123')

      expect(response).to redirect_to('/admissions/thank-you')
      applicant = Admissions::Applicant.sole
      expect(applicant).to have_attributes(email: 'new.person@example.com', phone: '07700 900123', stage: 'eoi')
      follow_redirect!
      expect(Nokogiri::HTML(response.body).at('main strong').text).to eq "Thank you — we've received your details."
      expect(response.body).not_to include('eoi-form')
    end

    it 'stores no IP address in the record or the event log' do
      post_eoi
      applicant = Admissions::Applicant.sole
      stored = [applicant.attributes, *applicant.events.map(&:attributes)].to_s
      expect(stored).not_to include('127.0.0.1')
      expect(stored).not_to include(request.remote_ip)
    end

    it 'shows the same thank-you, and makes no second record, for an address already known' do
      post_eoi(email: 'known@example.com')
      first_redirect = response.location
      post_eoi(email: 'KNOWN@example.com')

      expect(response.location).to eq first_redirect
      expect(Admissions::Applicant.count).to eq 1
      expect(Admissions::Applicant.sole.events.map(&:kind)).to include('eoi_repeated')
    end

    it 'says what to fix, keeps what was typed, and saves nothing when the address is wrong' do
      post_eoi(email: 'name@gmail', phone: '12')

      expect(response).to have_http_status(:unprocessable_entity)
      page = Nokogiri::HTML(response.body)
      expect(page.at('#eoi-email-error').text).to eq "That doesn't look like an email address. Please check it."
      expect(page.at('#eoi-phone-error').text).to eq "That doesn't look like a phone number. You can leave it blank."
      expect(page.at('#eoi_email')['value']).to eq 'name@gmail'
      expect(page.at('.eoi-privacy')).to be_present
      expect(Admissions::Applicant.count).to eq 0
    end

    it 'copes with a malformed submission' do
      post '/admissions', params: { eoi: 'nonsense' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(Admissions::Applicant.count).to eq 0
    end

    it 'sends nothing for real: in test, automatic email is only recorded' do
      round.update!(email_modes: { 'confirmation' => 'automatic' })
      post_eoi
      expect(recorded_emails.map(&:to)).to eq ['new.person@example.com']
      expect(Admissions::Delivery.adapter).to be_a(Admissions::Delivery::Recording)
    end
  end

  describe 'the honeypot' do
    it 'gives a bot the ordinary thank-you and saves nothing' do
      post_eoi(website: 'https://spam.example')

      expect(response).to redirect_to('/admissions/thank-you')
      expect(Admissions::Applicant.count).to eq 0
      expect(Admissions::Email.count).to eq 0
    end
  end

  describe 'the rate limit' do
    let(:limit) { Admissions::EoiFormController::RATE_LIMIT }

    it "takes #{Admissions::EoiFormController::RATE_LIMIT} submissions an hour from one address, then refuses" do
      limit.times { |i| post_eoi(email: "person#{i}@example.com") }
      expect(Admissions::Applicant.count).to eq limit

      post_eoi(email: 'one.too.many@example.com')

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include('Too many forms have been sent from your connection in the last hour')
      expect(Admissions::Applicant.count).to eq limit
    end

    it 'logs each refusal, naming no IP and no address' do
      allow(Rails.logger).to receive(:warn).and_call_original
      limit.times { |i| post_eoi(email: "person#{i}@example.com") }
      expect(Rails.logger).not_to have_received(:warn).with(/rate limit/)

      post_eoi(email: 'one.too.many@example.com')

      expect(Rails.logger).to have_received(:warn).with('[admissions] EOI rate limit hit; submission refused').once
    end

    it 'counts each address separately' do
      limit.times { |i| post_eoi(email: "person#{i}@example.com") }
      post '/admissions', params: { eoi: { email: 'elsewhere@example.com' } },
                          headers: { 'REMOTE_ADDR' => '203.0.113.9' }
      expect(response).to redirect_to('/admissions/thank-you')
    end

    it 'lets the address in again after an hour' do
      limit.times { |i| post_eoi(email: "person#{i}@example.com") }
      Timecop.travel(61.minutes.from_now) do
        post_eoi(email: 'later@example.com')
        expect(response).to redirect_to('/admissions/thank-you')
      end
    end

    it 'counts honeypot hits too' do
      limit.times { post_eoi(website: 'spam') }
      post_eoi
      expect(response).to have_http_status(:too_many_requests)
    end

    it 'keys the count on a hash, never the address itself' do
      post_eoi
      keys = Rails.cache.instance_variable_get(:@data).keys
      expect(keys.size).to eq 1
      expect(keys.first).to match(%r{\Arate-limit:admissions/eoi_form:\h{64}\z})
    end

    it 'never limits looking at the form' do
      (limit + 1).times { get '/admissions' }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'when the form is closed' do
    def expect_closed
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("We're not taking expressions of interest just now.")
      expect(response.body).not_to include('eoi-form')
    end

    it 'says so, and saves nothing, when every round has closed' do
      round.update!(closed_at: 1.day.ago)

      get '/admissions'
      expect_closed
      post_eoi
      expect_closed
      expect(Admissions::Applicant.count).to eq 0
    end

    it 'says so, and saves nothing, when there is no privacy notice' do
      allow(Admissions::EoiForm).to receive(:privacy_notice).and_return(nil)

      get '/admissions'
      expect_closed
      post_eoi
      expect_closed
      expect(Admissions::Applicant.count).to eq 0
    end

    it 'says so for an invalid submission too, rather than asking for corrections' do
      round.update!(closed_at: 1.day.ago)
      post_eoi(email: 'nope')
      expect_closed
    end
  end
end
