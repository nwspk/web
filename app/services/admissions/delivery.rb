module Admissions
  # How an approved email leaves the building (SPEC §9 "Email"). An adapter
  # takes a Message and returns a Receipt, or raises Delivery::Error, in
  # which case nothing was sent and the email stays held.
  #
  # - Recording keeps mail in memory and logs a line. It is the only adapter
  #   in test and development: nothing is ever sent from either.
  # - Gmail sends as admissions@newspeak.house through the Gmail API. It is
  #   production's adapter, and refuses to run until its environment
  #   variables are set (Gmail::VARIABLES). ADMISSIONS_EMAIL_DELIVERY=recording
  #   switches a production host (staging, say) to recording instead.
  module Delivery
    Message = Struct.new(:to, :subject, :body, :email_id, keyword_init: true)
    Receipt = Struct.new(:delivery, :message_id, keyword_init: true)

    class Error < StandardError; end
    class NotConfigured < Error; end

    ADAPTERS = %w[gmail recording].freeze

    class << self
      # Tests may swap in a stub; otherwise built once, on first use.
      attr_writer :adapter

      def adapter
        @adapter ||= build
      end
    end

    def self.build(env: ENV, rails_env: Rails.env)
      return Recording.new unless rails_env.production?

      choice = env['ADMISSIONS_EMAIL_DELIVERY'].presence || 'gmail'
      unless ADAPTERS.include?(choice)
        raise NotConfigured, "ADMISSIONS_EMAIL_DELIVERY must be one of #{ADAPTERS.join(', ')}"
      end

      choice == 'gmail' ? Gmail.new(env: env) : Recording.new
    end
  end
end
