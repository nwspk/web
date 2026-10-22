module Admissions
  # A card created by hand by staff (SPEC §3a "Cards created by hand"):
  # someone who emailed directly, someone met at an event, or an EOI from the
  # old Google Form. It takes an email address (required), a phone and a name
  # (optional), the round, any funnel stage, and optionally the date the
  # person first expressed interest, which the `created` event keeps as
  # details['first_interest_on'] so funnel-stats can count the EOI from its
  # real date (Applicant#first_interest_on reads it back).
  #
  # It then sends whichever of the stage's emails staff ticked, each through
  # EmailSender#send_now!: staff saw the preview, so the click is the
  # approval. Only `eoi` offers any (the confirmation and the holding email)
  # until later phases add the others. Nothing is ticked by default.
  #
  # The card and its emails are one transaction, and EmailSender sends only
  # once it commits; an email that can't be drafted (no template, say)
  # creates nothing. The same address in the same round (any case) is
  # refused, naming the existing card (#existing), never made twice. The
  # card links to the person's latest record in an earlier round, as the
  # eoi-form does.
  class CardByHand
    include ActiveModel::Model
    include ActiveModel::Attributes

    OFFERED_EMAILS = { 'eoi' => %w[confirmation holding] }.freeze

    attribute :round_id, :integer
    attribute :email, :string
    attribute :phone, :string
    attribute :name, :string
    attribute :stage, :string, default: 'eoi'
    attribute :first_interest_on, :date

    attr_reader :applicant, :emails, :existing

    validate :round_exists
    validate :stage_is_a_funnel_stage
    validate :email_is_an_address
    validate :address_new_in_round
    validate :phone_short
    validate :first_interest_on_a_past_date
    validate :ticked_emails_offered

    def email=(value)
      super(value.to_s.strip)
    end

    def phone=(value)
      super(value.to_s.strip.presence)
    end

    def name=(value)
      super(value.to_s.squish.presence)
    end

    # Kept as typed, so a date that doesn't parse is reported, not ignored.
    def first_interest_on=(value)
      @first_interest_on_typed = value
      super
    end

    # The email types ticked to send.
    def send_emails = @send_emails || []

    def send_emails=(types)
      @send_emails = Array(types).compact_blank.map(&:to_s).uniq
    end

    def round
      @round = nil if @round && @round.id != round_id
      @round ||= round_id && Round.find_by(id: round_id)
    end

    def offered_emails = OFFERED_EMAILS.fetch(stage, [])

    # Each offered email as it would go to this person, by type: the
    # rendered subject and body, or the reason it can't be drafted (no
    # template, or a placeholder this card can't fill).
    Preview = Struct.new(:type, :label, :subject, :body, :problem, keyword_init: true) do
      def sendable? = problem.nil?
    end

    def previews
      return [] unless round

      person = Applicant.new(round: round, email: email, phone: phone, name: name, stage: stage)
      offered_emails.map do |type|
        preview(type, person)
      end
    end

    # A fingerprint of the previews, so a card is never created sending a
    # text other than the one staff were shown.
    def preview_digest
      Digest::SHA256.hexdigest(previews.map { |p| [p.type, p.subject, p.body, p.problem].join("\0") }.join("\0\0"))
    end

    def save(actor)
      return false unless valid?

      ActiveRecord::Base.transaction do
        @applicant = ApplicantChanges.new(actor).create!(
          round: round, email: email, phone: phone, name: name, stage: stage,
          previous_applicant: earlier_record, details: created_details
        )
        sender = EmailSender.new(actor)
        @emails = send_emails.map { |type| sender.send_now!(@applicant, type) }
      end
      @emails.each(&:reload)
      true
    rescue ActiveRecord::RecordInvalid => e
      raise unless e.record.errors.of_kind?(:email, :taken)

      # Another request created the same address first.
      address_new_in_round
      false
    rescue EmailSender::MissingTemplate, EmailTemplate::RenderError => e
      errors.add(:base, "Nothing was created: #{e.message}")
      false
    end

    private

    def preview(type, person)
      template = round.email_template(type)
      unless template
        return Preview.new(type: type, label: EmailTypes.label(type),
                           problem: "There is no #{EmailTypes.label(type)} template for #{round.name} yet")
      end

      rendered = template.render(person)
      Preview.new(type: type, label: EmailTypes.label(type), subject: rendered.subject, body: rendered.body)
    rescue EmailTemplate::RenderError => e
      Preview.new(type: type, label: EmailTypes.label(type), problem: e.message)
    end

    def created_details
      { 'via' => 'by_hand', 'first_interest_on' => first_interest_on&.iso8601 }.compact
    end

    def earlier_record
      Applicant.where.not(round_id: round.id).where('lower(email) = ?', email.downcase).order(id: :desc).first
    end

    def round_exists
      errors.add(:round_id, 'Choose a round.') unless round
    end

    def stage_is_a_funnel_stage
      errors.add(:stage, 'Choose a stage.') unless Stages::FUNNEL.include?(stage)
    end

    def email_is_an_address
      if email.blank?
        errors.add(:email, 'Enter their email address.')
      elsif email.length > EoiForm::EMAIL_MAX_LENGTH || !email.match?(URI::MailTo::EMAIL_REGEXP)
        errors.add(:email, "That doesn't look like an email address.")
      end
    end

    def address_new_in_round
      return unless round && email.present?

      @existing = round.applicants.find_by('lower(email) = ?', email.downcase)
      errors.add(:email, "#{round.name} already has a card for this address.") if @existing
    end

    def phone_short
      return if phone.nil? || phone.length <= EoiForm::PHONE_MAX_LENGTH

      errors.add(:phone, "That doesn't look like a phone number.")
    end

    def first_interest_on_a_past_date
      if @first_interest_on_typed.present? && first_interest_on.nil?
        errors.add(:first_interest_on, "That isn't a date.")
      elsif first_interest_on && first_interest_on > Date.current
        errors.add(:first_interest_on, "That's in the future.")
      end
    end

    def ticked_emails_offered
      unknown = send_emails - offered_emails
      return if unknown.empty?

      labels = unknown.map { |type| EmailTypes::TYPES.fetch(type, type) }
      errors.add(:send_emails, "A card at this stage can't send #{labels.to_sentence}.")
    end
  end
end
