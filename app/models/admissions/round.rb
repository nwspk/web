module Admissions
  # A minimal admissions round (SPEC §7): enough for applicants to belong to
  # one. Fees, pot and email modes (round-config, SPEC §2) come later.
  class Round < ActiveRecord::Base
    has_many :applicants, class_name: 'Admissions::Applicant', inverse_of: :round, dependent: :restrict_with_exception

    validates :name, presence: true, uniqueness: true
    validate :dates_in_order

    def closed?
      closed_at.present?
    end

    # Applications are open from the invitation date until Ed closes the
    # round (closing is a manual act, SPEC §7; closes_on is the plan).
    def applications_open?(on: Date.current)
      invites_on.present? && invites_on <= on && !closed?
    end

    private

    def dates_in_order
      dates = [opens_on, invites_on, closes_on]
      present = dates.compact
      errors.add(:base, 'Round dates must run open, invite, close') unless present == present.sort
    end
  end
end
