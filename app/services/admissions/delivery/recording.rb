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
        Rails.logger.info("[admissions] email ##{message.email_id} recorded, not sent (recording delivery)")
        Receipt.new(delivery: 'recording', message_id: "recorded-#{SecureRandom.hex(8)}")
      end
    end
  end
end
