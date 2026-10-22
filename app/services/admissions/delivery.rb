module Admissions
  # How an approved email leaves the building (SPEC §9 "Email"). An adapter
  # takes a Message and returns a Receipt, or raises:
  #
  # - NotSent when the message certainly did not go (the service refused it,
  #   or was never reached): the email goes back to held;
  # - OutcomeUnknown when it may have gone (the connection dropped after the
  #   request was written): the email stays sending until staff check the
  #   admissions@ Sent folder and say which.
  #
  # - Recording logs a line, and in tests also keeps each message in memory.
  #   It is the only adapter in test and development: nothing is ever sent
  #   from either.
  # - Gmail sends as admissions@newspeak.house through the Gmail API. It is
  #   production's adapter, and refuses to run until its environment
  #   variables are set (Gmail::VARIABLES). ADMISSIONS_EMAIL_DELIVERY=recording
  #   switches a production host (staging, say) to recording instead.
  module Delivery
    Message = Struct.new(:to, :subject, :body, :email_id, keyword_init: true)
    Receipt = Struct.new(:delivery, :message_id, keyword_init: true)

    class Error < StandardError; end
    class NotSent < Error; end
    class NotConfigured < NotSent; end
    class OutcomeUnknown < Error; end

    ADAPTERS = %w[gmail recording].freeze

    class << self
      # Tests may swap in a stub; otherwise built once, on first use.
      attr_writer :adapter

      def adapter
        @adapter ||= build
      end

      BOOT_WARNING = '[admissions] ADMISSIONS_EMAIL_DELIVERY=recording: admissions email is only ' \
                     'recorded, and nothing is actually sent from this site'.freeze

      # Said once at boot by a production host set to record, so nobody
      # mistakes a rehearsal site for one that sends.
      def warn_if_recording(env: ENV, rails_env: Rails.env, logger: Rails.logger)
        logger.warn(BOOT_WARNING) if rails_env.production? && env['ADMISSIONS_EMAIL_DELIVERY'] == 'recording'
      end

      # Whether this site only records mail, decided without building the
      # Gmail adapter (which refuses to build when unconfigured).
      def recording?(env: ENV, rails_env: Rails.env)
        return adapter.is_a?(Recording) if @adapter

        !rails_env.production? || env['ADMISSIONS_EMAIL_DELIVERY'] == 'recording'
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
