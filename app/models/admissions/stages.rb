module Admissions
  # The stage machine's rules (SPEC §3, §3a): which stages exist, which moves
  # are legal, and who may make them. Pure data and predicates; the changes
  # themselves are made only by Admissions::ApplicantChanges.
  module Stages
    FUNNEL = %w[
      eoi invited applied task_sent task_returned interview_offered
      interview_booked interviewed offered accepted contracts_sent confirmed
    ].freeze
    ON_HOLD = 'on_hold'.freeze
    # deferred = not this year: kept, and reminded when the next round opens.
    # withdrawn = remove my details: scrubbed to an anonymised stub. Someone
    # dropping out is deferred, not withdrawn, unless they ask for removal.
    EXITS = %w[deferred declined rejected withdrawn].freeze
    ALL = (FUNNEL + [ON_HOLD] + EXITS).freeze
    TERMINAL = (['confirmed'] + EXITS).freeze

    ACTOR_TYPES = %w[staff applicant system].freeze

    # Legal transitions along the funnel, each with who may make it. Staff
    # may always act on an applicant's behalf (e.g. after an email).
    TRANSITIONS = {
      %w[eoi invited] => %w[staff system], # bulk invite; auto-invite in round
      %w[invited applied] => %w[applicant staff],
      %w[applied task_sent] => %w[staff],
      %w[task_sent task_returned] => %w[applicant staff],
      %w[task_returned interview_offered] => %w[staff],
      %w[interview_offered interview_booked] => %w[applicant staff],
      %w[interview_booked interview_offered] => %w[applicant staff], # cancelled booking, re-pick
      %w[interview_booked interviewed] => %w[staff],
      %w[interviewed offered] => %w[staff],
      %w[offered accepted] => %w[applicant staff],
      %w[accepted contracts_sent] => %w[staff],
      %w[contracts_sent confirmed] => %w[staff]
    }.freeze

    # Exit states are reachable from any stage that is not itself an exit
    # (on_hold included); withdrawal is also reachable from the other exits,
    # since a removal request can come at any time.
    EXIT_ACTORS = {
      'deferred' => %w[applicant staff system], # system: round close
      'declined' => %w[applicant staff],
      'rejected' => %w[staff],
      'withdrawn' => %w[applicant staff]
    }.freeze

    HOLD_ACTORS = %w[applicant staff].freeze
    RETURN_ACTORS = %w[applicant staff].freeze
    REOPEN_ACTORS = %w[applicant staff].freeze
    MOVE_ACTORS = %w[staff].freeze
    FLAG_ACTORS = %w[staff].freeze
    NOTE_ACTORS = %w[staff].freeze
    DETAILS_ACTORS = %w[applicant staff].freeze

    # Who each funnel stage waits on (SPEC §3 "Waiting on"). `eoi` waits on a
    # date until applications open, then on staff to invite.
    WAITING_ON = {
      'eoi' => :date,
      'invited' => :applicant,
      'applied' => :staff,
      'task_sent' => :applicant,
      'task_returned' => :staff,
      'interview_offered' => :applicant,
      'interview_booked' => :date,
      'interviewed' => :staff,
      'offered' => :applicant,
      'accepted' => :staff,
      'contracts_sent' => :applicant
    }.freeze

    NEXT_STEP = {
      'eoi' => 'Applications to open, then an invitation',
      'invited' => 'Applicant to complete the application form',
      'applied' => 'Staff to review the application and send the task',
      'task_sent' => 'Applicant to return their task answer',
      'task_returned' => 'Staff to review the task and offer an interview',
      'interview_offered' => 'Applicant to book an interview slot',
      'interview_booked' => 'The interview to happen',
      'interviewed' => 'Staff to decide',
      'offered' => 'Applicant to accept or decline the offer',
      'accepted' => 'Staff to issue contracts',
      'contracts_sent' => 'Applicant to sign the contracts',
      ON_HOLD => 'Hold to end on its return date',
      :complicated => 'Staff to check back on this case'
    }.freeze

    # How staff screens name each state.
    LABELS = {
      'eoi' => 'EOI', 'invited' => 'Invited', 'applied' => 'Applied', 'task_sent' => 'Task sent',
      'task_returned' => 'Task returned', 'interview_offered' => 'Interview offered',
      'interview_booked' => 'Interview booked', 'interviewed' => 'Interviewed', 'offered' => 'Offered',
      'accepted' => 'Accepted', 'contracts_sent' => 'Contracts sent', 'confirmed' => 'Confirmed',
      'on_hold' => 'On hold', 'deferred' => 'Deferred', 'declined' => 'Declined', 'rejected' => 'Rejected',
      'withdrawn' => 'Withdrawn'
    }.freeze

    module_function

    def label(stage) = LABELS.fetch(stage)

    def terminal?(stage) = TERMINAL.include?(stage)
    def exit?(stage) = EXITS.include?(stage)

    def transition_actors(from, to) = TRANSITIONS.fetch([from, to], [])
    def transition?(from, to) = TRANSITIONS.key?([from, to])

    def exit_reachable?(from, to)
      return false unless EXITS.include?(to)
      return from != 'withdrawn' if to == 'withdrawn'

      !exit?(from)
    end

    # on_hold is reachable from any non-terminal funnel stage.
    def holdable?(stage) = FUNNEL.include?(stage) && !terminal?(stage)
  end
end
