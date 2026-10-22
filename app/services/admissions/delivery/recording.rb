module Admissions
  module Delivery
    # Sends nothing: logs a line for each message, without its text, and in
    # tests keeps the message in memory for the test to inspect. Nowhere
    # else does it hold addresses or bodies. The default in test and
    # development; a production host (staging) uses it only when told to.
    class Recording
      @deliveries = []

      class << self
        attr_reader :deliveries

        def clear!
          @deliveries.clear
        end
      end

      def deliver(message)
        self.class.deliveries << message if Rails.env.test?
        Rails.logger.info("[admissions] #{description(message)} recorded, not sent (recording delivery)")
        Receipt.new(delivery: 'recording', message_id: "recorded-#{SecureRandom.hex(8)}")
      end

      private

      # Names the message without its text or addresses.
      def description(message)
        what = message.email_id ? "email ##{message.email_id}" : 'staff email'
        file = message.attachment
        file ? "#{what} with #{file.filename} (#{file.content.bytesize} bytes)" : what
      end
    end
  end
end
