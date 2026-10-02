module Admissions
  # An admissions round and its settings (SPEC §2 round-config, §3a, §7):
  # dates, money, the mode of each email type, and the timings that give
  # every applicant a due time. Only admissions leads change it (Ability).
  class Round < ActiveRecord::Base
    DEFAULT_DAYS = 7
    MONEY_FIELDS = %i[programme_fee accommodation_monthly scholarship_pot].freeze

    has_many :applicants, class_name: 'Admissions::Applicant', inverse_of: :round, dependent: :restrict_with_exception

    validates :name, presence: true, uniqueness: true
    validates :reminder_interval_days, numericality: { only_integer: true, in: 1..365 }
    validates(*MONEY_FIELDS.map { |f| :"#{f}_pence" },
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true)
    validate :dates_in_order
    validate :email_modes_known
    validate :staff_turnarounds_known
    validate :money_parsed
    after_save { @money_input = @money_errors = nil }

    # Stages that wait on staff, each with a turnaround target (SPEC §3a).
    # `eoi` waits on a date until applications open, then on staff to invite.
    def self.staff_stages
      ['eoi'] + Stages::WAITING_ON.select { |_, who| who == :staff }.keys
    end

    def closed?
      closed_at.present?
    end

    # Applications are open from the invitation date until Ed closes the
    # round (closing is a manual act, SPEC §7; closes_on is the plan).
    def applications_open?(on: Date.current)
      invites_on.present? && invites_on <= on && !closed?
    end

    def email_mode(type)
      raise ArgumentError, "unknown email type #{type}" unless EmailTypes::TYPES.key?(type)

      email_modes.fetch(type, EmailTypes::DEFAULT_MODE)
    end

    def staff_turnaround(stage)
      raise ArgumentError, "#{stage} does not wait on staff" unless self.class.staff_stages.include?(stage)

      staff_turnaround_days.fetch(stage, DEFAULT_DAYS).days
    end

    def reminder_interval
      reminder_interval_days.days
    end

    MONEY_FIELDS.each do |field|
      define_method(field) do
        pence = public_send(:"#{field}_pence")
        pence && Money.new(pence, 'GBP')
      end

      # Pounds as typed on the settings form ("3000" or "3,000.00"); blank
      # clears the amount.
      define_method(:"#{field}_pounds") do
        return @money_input[field] if @money_input&.key?(field)

        amount = public_send(field)
        amount && amount.to_d.to_s('F').delete_suffix('.0')
      end

      define_method(:"#{field}_pounds=") do |value|
        (@money_input ||= {})[field] = value
        @money_errors&.delete(field)
        text = value.to_s.strip.delete(',').delete_prefix('£')
        if text.empty?
          public_send(:"#{field}_pence=", nil)
        elsif text.match?(/\A\d+(\.\d{1,2})?\z/)
          public_send(:"#{field}_pence=", (BigDecimal(text) * 100).to_i)
        else
          (@money_errors ||= []) << field
        end
      end
    end

    private

    def dates_in_order
      present = [opens_on, invites_on, closes_on].compact
      errors.add(:base, 'Round dates must run open, invite, close') unless present == present.sort
    end

    def email_modes_known
      unknown = email_modes.keys - EmailTypes.keys
      errors.add(:email_modes, "has unknown email types: #{unknown.join(', ')}") if unknown.any?
      bad = email_modes.values - EmailTypes::MODES.keys
      errors.add(:email_modes, "has unknown modes: #{bad.uniq.join(', ')}") if bad.any?
    end

    def staff_turnarounds_known
      unknown = staff_turnaround_days.keys - self.class.staff_stages
      errors.add(:staff_turnaround_days, "has stages that don't wait on staff: #{unknown.join(', ')}") if unknown.any?
      return if staff_turnaround_days.values.all? { |d| d.is_a?(Integer) && d.between?(1, 365) }

      errors.add(:staff_turnaround_days, 'must be whole days between 1 and 365')
    end

    def money_parsed
      Array(@money_errors).uniq.each do |field|
        errors.add(:"#{field}_pounds", 'must be an amount in pounds, like 3000 or 1100.50')
      end
    end
  end
end
