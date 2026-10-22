module Admissions
  # The eoi-form's own wording (SPEC §2 eoi-form, §9b): its introduction and
  # its privacy notice. Both are Ed's words, so they live only in the
  # database, never in this public repository (SPEC §9).
  #
  # Each save is a new version, attributed to the lead who wrote it; the
  # current text is the latest version of its key, and the earlier ones are
  # the log. Versions are never changed or deleted (a database trigger holds
  # that), so the privacy notice an applicant saw can always be read back:
  # their `created` event names its version.
  class FormText < ActiveRecord::Base
    KEYS = {
      'eoi_introduction' => 'Introduction',
      'privacy_notice' => 'Privacy notice'
    }.freeze
    # The form opens only once a privacy notice is set, so the notice can't
    # be cleared, only replaced. The introduction may be blank.
    REQUIRED = %w[privacy_notice].freeze

    belongs_to :created_by_user, class_name: 'User'

    validates :key, inclusion: { in: KEYS.keys }
    validates :created_by_user, presence: true
    validates :body, presence: true, if: -> { REQUIRED.include?(key) }
    validates :body, length: { maximum: 20_000 }

    before_validation { self.body = body.to_s.gsub("\r\n", "\n").strip }

    def readonly?
      persisted? || super
    end

    def self.label(key) = KEYS.fetch(key)

    # The latest version of a key, or nil if it has never been written.
    def self.current(key)
      raise ArgumentError, "unknown form text #{key}" unless KEYS.key?(key)

      where(key: key).order(:id).last
    end

    def self.history(key) = where(key: key).order(id: :desc).includes(:created_by_user)

    # The current wording, or nil when unset or blank.
    def self.text(key) = current(key)&.body.presence

    def label = self.class.label(key)
  end
end
