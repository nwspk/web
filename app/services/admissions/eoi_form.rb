module Admissions
  # The eoi-form (SPEC §2, §3 stage `eoi`, §7): the public form at
  # /admissions where anyone can express interest with an email address and,
  # if they like, a phone number. Nothing else, matching the Google Form it
  # replaces.
  #
  #   form = Admissions::EoiForm.new(email: '…', phone: '…')
  #   form.save   # false when invalid; raises Closed when the form is closed
  #
  # The form is open only while a privacy notice is set and some round has
  # not closed (.closed_reasons says which is missing). An EOI joins the
  # earliest unclosed round (.round), at stage `eoi`, as the applicant, with
  # the privacy notice's version recorded on its `created` event. It then
  # asks the email-sender for the confirmation, and for the holding email
  # too while that round's applications aren't open, each under its email
  # mode. That all happens in one transaction, and the email-sender sends
  # only after it commits, so an EOI that fails to save emails nobody; and
  # an email that can't be drafted (no template, say) is logged, never
  # raised, so it never loses an EOI.
  #
  # The same address again in the same round (any case) makes no second
  # record: an `eoi_repeated` event on the first, and no new email. The
  # form says the same thank-you either way, so it never reveals whether an
  # address is known (SPEC §9b). Someone from an earlier round gets a fresh
  # record linked to their latest earlier one. A withdrawn record has no
  # address left, so a withdrawn person who comes back is simply new.
  #
  # The auto-invite of an EOI arriving while applications are open (SPEC
  # §7) needs the application-form, which is phase 2; nothing is drafted
  # for it yet.
  class EoiForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    class Closed < StandardError; end

    EMAIL_MAX_LENGTH = 254
    # Loose on purpose: people write phone numbers every which way.
    PHONE_MAX_LENGTH = 40
    PHONE_MIN_DIGITS = 6

    attribute :email, :string
    attribute :phone, :string

    # Set by #save: :created or :repeated, and the applicant concerned.
    attr_reader :outcome, :applicant

    validate :email_is_an_address
    validate :phone_is_loosely_a_phone_number

    # The round an EOI joins now: the earliest that hasn't closed, by its
    # opening date (rounds with none last), then by when it was created.
    def self.round
      Round.where(closed_at: nil).order(Arel.sql('opens_on ASC NULLS LAST'), :id).first
    end

    def self.privacy_notice = FormText.current('privacy_notice')

    # Why the form is closed: any of :no_privacy_notice and :no_open_round,
    # or none when it is open.
    def self.closed_reasons
      reasons = []
      reasons << :no_privacy_notice if privacy_notice&.body.blank?
      reasons << :no_open_round unless round
      reasons
    end

    def self.open? = closed_reasons.empty?

    def email=(value)
      super(value.to_s.strip)
    end

    def phone=(value)
      super(value.to_s.strip.presence)
    end

    def save
      return false unless valid?

      attempts = 0
      begin
        attempts += 1
        ActiveRecord::Base.transaction { submit }
      rescue ActiveRecord::RecordInvalid => e
        # A first EOI for the same address, racing this one, won the unique
        # index: this one is now a repeat of it.
        raise unless attempts == 1 && e.record.errors.of_kind?(:email, :taken)

        retry
      end
      true
    end

    private

    def submit
      round = self.class.round
      notice = self.class.privacy_notice
      raise Closed, 'the EOI form is closed' unless round && notice&.body.present?

      existing = round.applicants.lock.find_by('lower(email) = ?', email.downcase)
      if existing
        ApplicantChanges.new(Actor.applicant(existing)).record_repeat_eoi!(existing, phone: phone)
        @outcome = :repeated
        @applicant = existing
        return
      end

      @applicant = ApplicantChanges.new(Actor.applicant).create!(
        round: round, email: email, phone: phone, previous_applicant: earlier_record(round),
        details: { 'via' => 'eoi_form', 'privacy_notice_version' => notice.id }
      )
      @outcome = :created
      EmailSender.request_automatic!(@applicant, 'confirmation')
      EmailSender.request_automatic!(@applicant, 'holding') unless round.applications_open?
    end

    # The same person's latest record in another round, if any.
    def earlier_record(round)
      Applicant.where.not(round_id: round.id).where('lower(email) = ?', email.downcase).order(id: :desc).first
    end

    def email_is_an_address
      if email.blank?
        errors.add(:email, 'Please enter your email address.')
      elsif email.length > EMAIL_MAX_LENGTH || !email.match?(URI::MailTo::EMAIL_REGEXP) ||
            !email.split('@', 2).last.include?('.')
        # A domain with no dot is nearly always a slip ("name@gmail").
        errors.add(:email, "That doesn't look like an email address. Please check it.")
      end
    end

    def phone_is_loosely_a_phone_number
      return if phone.nil?
      return if phone.length <= PHONE_MAX_LENGTH && phone.count('0-9') >= PHONE_MIN_DIGITS

      errors.add(:phone, "That doesn't look like a phone number. You can leave it blank.")
    end
  end
end
