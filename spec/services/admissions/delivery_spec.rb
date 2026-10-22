require 'rails_helper'

RSpec.describe Admissions::Delivery do
  let(:gmail_env) do
    { 'ADMISSIONS_GMAIL_CLIENT_ID' => 'fake-id', 'ADMISSIONS_GMAIL_CLIENT_SECRET' => 'fake-secret',
      'ADMISSIONS_GMAIL_REFRESH_TOKEN' => 'fake-refresh' }
  end
  let(:production) { ActiveSupport::StringInquirer.new('production') }

  describe '.build' do
    it 'records in test and development, whatever the environment says' do
      %w[test development].each do |env|
        adapter = described_class.build(env: gmail_env.merge('ADMISSIONS_EMAIL_DELIVERY' => 'gmail'),
                                        rails_env: ActiveSupport::StringInquirer.new(env))
        expect(adapter).to be_a described_class::Recording
      end
    end

    it 'is the test suite’s adapter' do
      expect(described_class.adapter).to be_a described_class::Recording
    end

    it 'uses Gmail in production once its variables are set' do
      expect(described_class.build(env: gmail_env, rails_env: production)).to be_a described_class::Gmail
    end

    it 'refuses in production until they are, naming each missing variable and no value' do
      expect { described_class.build(env: gmail_env.except('ADMISSIONS_GMAIL_REFRESH_TOKEN'), rails_env: production) }
        .to raise_error(described_class::NotConfigured,
                        'Gmail delivery is not configured: set ADMISSIONS_GMAIL_REFRESH_TOKEN in the environment')
      expect { described_class.build(env: {}, rails_env: production) }
        .to raise_error(described_class::NotConfigured, /ADMISSIONS_GMAIL_CLIENT_ID, ADMISSIONS_GMAIL_CLIENT_SECRET, ADMISSIONS_GMAIL_REFRESH_TOKEN/)
      expect { described_class.build(env: gmail_env.merge('ADMISSIONS_GMAIL_CLIENT_ID' => ''), rails_env: production) }
        .to raise_error(described_class::NotConfigured) { |e| expect(e.message).not_to include('fake') }
    end

    it 'records in production when told to' do
      adapter = described_class.build(env: { 'ADMISSIONS_EMAIL_DELIVERY' => 'recording' }, rails_env: production)
      expect(adapter).to be_a described_class::Recording
      expect { described_class.build(env: { 'ADMISSIONS_EMAIL_DELIVERY' => 'smtp' }, rails_env: production) }
        .to raise_error(described_class::NotConfigured, /must be one of gmail, recording/)
    end
  end

  describe '.recording? and the boot warning' do
    it 'is recording outside production, and in production only when told to' do
      described_class.adapter = nil
      expect(described_class.recording?(env: {}, rails_env: ActiveSupport::StringInquirer.new('development'))).to be true
      expect(described_class.recording?(env: {}, rails_env: production)).to be false
      expect(described_class.recording?(env: { 'ADMISSIONS_EMAIL_DELIVERY' => 'recording' }, rails_env: production))
        .to be true
    end

    it 'warns at boot only on a production host set to record' do
      logger = instance_double(Logger, warn: nil)
      described_class.warn_if_recording(env: { 'ADMISSIONS_EMAIL_DELIVERY' => 'recording' }, rails_env: production,
                                        logger: logger)
      expect(logger).to have_received(:warn).with(/nothing is actually sent from this site/)

      quiet = instance_double(Logger, warn: nil)
      described_class.warn_if_recording(env: {}, rails_env: production, logger: quiet)
      described_class.warn_if_recording(env: { 'ADMISSIONS_EMAIL_DELIVERY' => 'recording' },
                                        rails_env: ActiveSupport::StringInquirer.new('development'), logger: quiet)
      expect(quiet).not_to have_received(:warn)
    end
  end

  describe described_class::Recording do
    it 'holds no message in memory outside tests' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      message = Admissions::Delivery::Message.new(to: 'a@example.com', subject: 's', body: 'b', email_id: 1)
      expect(described_class.new.deliver(message).delivery).to eq 'recording'
      expect(described_class.deliveries).to be_empty
    end

    it 'keeps the message and logs a line without its text' do
      message = Admissions::Delivery::Message.new(to: 'a@example.com', subject: 'Secret subject', body: 'b', email_id: 7)
      expect(Rails.logger).to receive(:info).with('[admissions] email #7 recorded, not sent (recording delivery)')
      receipt = described_class.new.deliver(message)
      expect(receipt.delivery).to eq 'recording'
      expect(described_class.deliveries).to eq [message]
    end
  end

  describe described_class::Gmail do
    let(:message) do
      Admissions::Delivery::Message.new(to: 'applicant@example.com', subject: 'Test subject ✓',
                                        body: "Test body\nwith ünïcode", email_id: 3)
    end

    it 'sends the message as admissions@ through the client' do
      client = instance_double(Admissions::Delivery::Gmail::Client)
      raw = nil
      allow(client).to receive(:send_raw) { |r| raw = r and 'gmail-id-1' }

      receipt = described_class.new(env: gmail_env, client: client).deliver(message)

      expect(receipt.to_h).to eq(delivery: 'gmail', message_id: 'gmail-id-1')
      mail = Mail.new(Base64.urlsafe_decode64(raw))
      expect(mail.from).to eq ['admissions@newspeak.house']
      expect(mail.to).to eq ['applicant@example.com']
      expect(mail.subject).to eq 'Test subject ✓'
      # On the wire, lines end CRLF, as RFC 2822 requires.
      expect(mail.body.decoded.force_encoding('UTF-8')).to eq "Test body\r\nwith ünïcode"
      expect(mail.mime_type).to eq 'text/plain'
    end

    it 'refuses to start without its variables' do
      expect { described_class.new(env: {}) }.to raise_error(Admissions::Delivery::NotConfigured)
    end
  end

  describe Admissions::Delivery::Gmail::Client do
    let(:calls) { [] }

    def response(klass, code, body)
      klass.new('1.1', code, '').tap { |r| allow(r).to receive(:body).and_return(body) }
    end

    def client(responses)
      http = lambda do |uri, request|
        calls << [uri.to_s, request]
        responses.shift
      end
      described_class.new(client_id: 'fake-id', client_secret: 'fake-secret', refresh_token: 'fake-refresh', http: http)
    end

    let(:token) { response(Net::HTTPOK, '200', { access_token: 'fake-access', expires_in: 3599 }.to_json) }
    let(:sent) { response(Net::HTTPOK, '200', { id: 'gmail-id-1' }.to_json) }

    it 'gets an access token from the refresh token, then sends' do
      expect(client([token, sent]).send_raw('cmF3')).to eq 'gmail-id-1'

      expect(calls.map(&:first)).to eq ['https://oauth2.googleapis.com/token',
                                        'https://gmail.googleapis.com/gmail/v1/users/me/messages/send']
      expect(URI.decode_www_form(calls.first.last.body).to_h)
        .to eq('client_id' => 'fake-id', 'client_secret' => 'fake-secret', 'refresh_token' => 'fake-refresh',
               'grant_type' => 'refresh_token')
      send_request = calls.last.last
      expect(send_request['Authorization']).to eq 'Bearer fake-access'
      expect(JSON.parse(send_request.body)).to eq('raw' => 'cmF3')
    end

    it 'reuses the access token until it expires' do
      c = client([token, sent, response(Net::HTTPOK, '200', { id: 'gmail-id-2' }.to_json)])
      c.send_raw('a')
      expect(c.send_raw('b')).to eq 'gmail-id-2'
      expect(calls.count { |uri, _| uri.include?('token') }).to eq 1
    end

    it "reports Google's refusal as not sent, without echoing credentials" do
      refused = response(Net::HTTPForbidden, '403', { error: { status: 'PERMISSION_DENIED', message: 'x' } }.to_json)
      expect { client([token, refused]).send_raw('a') }
        .to raise_error(Admissions::Delivery::NotSent, 'Gmail refused to send the message (HTTP 403 PERMISSION_DENIED)')

      bad_token = response(Net::HTTPBadRequest, '400', { error: 'invalid_grant' }.to_json)
      expect { client([bad_token]).send_raw('a') }
        .to raise_error(Admissions::Delivery::NotSent, 'Gmail refused to get an access token (HTTP 400 invalid_grant)')
    end

    it 'calls a success it cannot read an unknown outcome' do
      garbled = response(Net::HTTPOK, '200', 'not json')
      expect { client([token, garbled]).send_raw('a') }.to raise_error(Admissions::Delivery::OutcomeUnknown)
      no_id = response(Net::HTTPOK, '200', '{}')
      expect { client([token, no_id]).send_raw('a') }.to raise_error(Admissions::Delivery::OutcomeUnknown)
    end

    describe 'over the wire (with Net::HTTP stubbed)' do
      def real_client
        described_class.new(client_id: 'fake-id', client_secret: 'fake-secret', refresh_token: 'fake-refresh')
      end

      it 'calls a failure to connect not sent' do
        allow_any_instance_of(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout) # rubocop:disable RSpec/AnyInstance
        expect { real_client.send_raw('a') }
          .to raise_error(Admissions::Delivery::NotSent, 'Gmail could not be reached (Net::OpenTimeout)')
      end

      it 'calls a timeout after the send request went out an unknown outcome' do
        c = real_client
        c.instance_variable_set(:@access_token, 'fake-access')
        c.instance_variable_set(:@expires_at, 1.hour.from_now)
        allow_any_instance_of(Net::HTTP).to receive(:start) # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Net::ReadTimeout) # rubocop:disable RSpec/AnyInstance
        expect { c.send_raw('a') }.to raise_error(Admissions::Delivery::OutcomeUnknown, /lost before it answered/)
      end

      it 'calls a timeout while getting the token not sent' do
        allow_any_instance_of(Net::HTTP).to receive(:start) # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Net::ReadTimeout) # rubocop:disable RSpec/AnyInstance
        expect { real_client.send_raw('a') }.to raise_error(Admissions::Delivery::NotSent)
      end
    end

    it 'keeps its secrets out of inspect' do
      expect(client([]).inspect).not_to include('fake')
    end

    it 'is backed by a suite-wide guard against reaching the network' do
      expect { Net::HTTP.get(URI('https://example.com/')) }.to raise_error(/Tests may not reach the network/)
    end

    it 'never reaches the network in tests' do
      real = described_class.new(client_id: 'fake-id', client_secret: 'fake-secret', refresh_token: 'fake-refresh')
      expect { real.send_raw('a') }.to raise_error(Admissions::Delivery::NotSent, /could not be reached/)
    end
  end
end
