module Admissions
  # The applicant email types (SPEC §4) and the modes an automatic one can be
  # in (SPEC §3a): automatic, ask me first (held for staff approval), or off.
  # Only the type is code; every email's wording lives in the database,
  # editable per round, so none is published in this public repository.
  #
  # Each type gets a mode in round settings. For the types staff send with a
  # button (invitation, task, interview invitation, offer, apologies,
  # contracts cover note) the click is the approval; the mode governs any
  # automatic send of that type, such as the auto-invite of a new EOI while
  # applications are open.
  module EmailTypes
    TYPES = {
      'confirmation' => 'EOI confirmation',
      'holding' => 'Holding email (EOI out of round)',
      'events_digest' => 'Monthly events digest',
      'invitation' => 'Invitation to apply',
      'task' => 'Task',
      'interview_invitation' => 'Interview invitation',
      'interview_confirmation' => 'Interview confirmation',
      'reference_request' => 'Reference request',
      'referee_reminder' => 'Referee reminder',
      'referee_thank_you' => 'Referee thank-you',
      'offer' => 'Offer',
      'apologies' => 'Apologies',
      'contracts_cover_note' => 'Contracts cover note',
      'invoice_cover_note' => 'Invoice cover note',
      'reminder' => 'Weekly reminder',
      'deferral_acknowledgement' => 'Deferral acknowledgement',
      'hold_acknowledgement' => 'Hold acknowledgement',
      'round_close' => 'Round close: see you next year',
      'next_round_reminder' => 'Next round open: reminder to deferred'
    }.freeze

    MODES = {
      'automatic' => 'Automatic',
      'ask_me_first' => 'Ask me first',
      'off' => 'Off'
    }.freeze
    DEFAULT_MODE = 'ask_me_first'.freeze

    def self.keys = TYPES.keys
    def self.label(type) = TYPES.fetch(type)
  end
end
