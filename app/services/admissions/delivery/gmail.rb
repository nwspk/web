require 'net/http'

module Admissions
  module Delivery
    # Sends as admissions@newspeak.house through the Gmail API (SPEC §9), so
    # sent mail and replies live together in the mailbox Ed reads.
    #
    # Configured only from the environment, as the site keeps its secrets
    # (nwspk/web#52): an OAuth client and a refresh token granted by the
    # admissions@ account with the gmail.send scope. Without all three it
    # refuses to start, naming the missing variables and never their values.
    class Gmail
      FROM = 'admissions@newspeak.house'.freeze
      VARIABLES = %w[
        ADMISSIONS_GMAIL_CLIENT_ID ADMISSIONS_GMAIL_CLIENT_SECRET ADMISSIONS_GMAIL_REFRESH_TOKEN
      ].freeze

      def initialize(env: ENV, client: nil)
        missing = VARIABLES.reject { |name| env[name].present? }
        if missing.any?
          raise NotConfigured, "Gmail delivery is not configured: set #{missing.join(', ')} in the environment"
        end

        @client = client || Client.new(client_id: env['ADMISSIONS_GMAIL_CLIENT_ID'],
                                       client_secret: env['ADMISSIONS_GMAIL_CLIENT_SECRET'],
                                       refresh_token: env['ADMISSIONS_GMAIL_REFRESH_TOKEN'])
      end

      def deliver(message)
        Receipt.new(delivery: 'gmail', message_id: @client.send_raw(self.class.raw(message)))
      end

      # The message as Gmail wants it: RFC 2822, base64url-encoded. Plain
      # text only.
      def self.raw(message)
        mail = Mail.new
        mail.from = FROM
        mail.to = message.to
        mail.subject = message.subject
        mail.charset = 'UTF-8'
        mail.body = message.body
        Base64.urlsafe_encode64(mail.to_s)
      end

      # The two HTTP calls Gmail needs: a fresh access token from the refresh
      # token, then users.messages.send. `http` performs a request; tests
      # replace it, so nothing in the test suite reaches Google.
      #
      # Any failure getting the token, an error Google returns, or a failure
      # to connect means the message was not sent (NotSent). Once the send
      # request may have been written, a timeout or dropped connection means
      # nobody knows (OutcomeUnknown).
      class Client
        TOKEN_URI = URI('https://oauth2.googleapis.com/token')
        SEND_URI = URI('https://gmail.googleapis.com/gmail/v1/users/me/messages/send')
        OPEN_TIMEOUT = 5
        READ_TIMEOUT = 15

        def initialize(client_id:, client_secret:, refresh_token:, http: method(:perform))
          @client_id = client_id
          @client_secret = client_secret
          @refresh_token = refresh_token
          @http = http
        end

        # Returns Gmail's id for the sent message.
        def send_raw(raw)
          request = Net::HTTP::Post.new(SEND_URI)
          request['Authorization'] = "Bearer #{access_token}"
          request['Content-Type'] = 'application/json'
          request.body = { raw: raw }.to_json
          id = parse(@http.call(SEND_URI, request), 'send the message')['id']
          id.presence || raise(OutcomeUnknown, 'Gmail answered without saying whether it sent the message')
        end

        # Keeps the secrets out of logs and error pages.
        def inspect
          "#<#{self.class.name}>"
        end

        private

        # Nothing has been sent while getting the token, whatever goes wrong.
        def access_token
          return @access_token if @access_token && Time.current < @expires_at

          request = Net::HTTP::Post.new(TOKEN_URI)
          request.set_form_data(client_id: @client_id, client_secret: @client_secret,
                                refresh_token: @refresh_token, grant_type: 'refresh_token')
          token = parse(@http.call(TOKEN_URI, request), 'get an access token')
          @expires_at = Time.current + (token['expires_in'].to_i - 60).seconds
          @access_token = token['access_token'].presence || raise(NotSent, 'Gmail gave no access token')
        rescue OutcomeUnknown => e
          raise NotSent, e.message
        end

        # What failed decides what we know: failing to connect means nothing
        # was written; failing once the request is being written means it
        # may have arrived.
        def perform(uri, request)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.open_timeout = OPEN_TIMEOUT
          http.read_timeout = READ_TIMEOUT
          begin
            http.start
          rescue StandardError => e
            raise NotSent, "Gmail could not be reached (#{e.class})"
          end
          begin
            http.request(request)
          rescue StandardError => e
            raise OutcomeUnknown, "the connection to Gmail was lost before it answered (#{e.class})"
          ensure
            http.finish if http.started?
          end
        end

        # An error Google returns means it did not act. Its own error code is
        # safe to show; the response never echoes our credentials. A success
        # we can't read leaves the outcome unknown.
        def parse(response, what)
          unless response.is_a?(Net::HTTPSuccess)
            code = begin
              error = JSON.parse(response.body.presence || '{}')['error']
              error.is_a?(Hash) ? error['status'] : error
            rescue JSON::ParserError
              nil
            end
            raise NotSent, "Gmail refused to #{what} (HTTP #{response.code}#{" #{code}" if code})"
          end

          JSON.parse(response.body.presence || '{}')
        rescue JSON::ParserError
          raise OutcomeUnknown, "Gmail's answer could not be read"
        end
      end
    end
  end
end
