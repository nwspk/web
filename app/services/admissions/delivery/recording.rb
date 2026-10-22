module Admissions
  module Delivery
    # Keeps every message in memory instead of sending it, and logs that it
    # did, without the text. The default in test and development.
    class Recording
      @deliveries = []

      class << self
        attr_reader :deliveries

        def clear!
          @deliveries.clear
        end
      end

      def deliver(message)
        self.class.deliveries << message
        Rails.logger.info("[admissions] email ##{message.email_id} recorded, not sent (recording delivery)")
        Receipt.new(delivery: 'recording', message_id: "recorded-#{SecureRandom.hex(8)}")
      end
    end
  end
end
