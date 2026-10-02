module Admissions
  # The log is the truth (SPEC §1): replays an applicant's events to rebuild
  # the state ApplicantChanges caches on the applicant row, and reports any
  # column where the two disagree. A disagreement means something changed the
  # row without going through ApplicantChanges.
  class StateRebuilder
    def self.rebuild(applicant)
      new(applicant.events.reorder(:id).to_a).state
    end

    # { field => { cached:, rebuilt: } } for each column that disagrees, read
    # from the database rather than from any unsaved copy in memory.
    def self.discrepancies(applicant)
      stored = Applicant.find(applicant.id)
      rebuilt = rebuild(stored)
      Applicant::STATE_FIELDS.each_with_object({}) do |field, out|
        cached = stored.public_send(field)
        out[field] = { cached: cached, rebuilt: rebuilt[field] } unless cached == rebuilt[field]
      end
    end

    def self.consistent?(applicant)
      discrepancies(applicant).empty?
    end

    # Every applicant whose cached state disagrees with its log.
    def self.inconsistent(scope = Applicant.all)
      scope.includes(:events).reject { |applicant| consistent?(applicant) }
    end

    attr_reader :state

    def initialize(events)
      @state = Applicant::STATE_FIELDS.index_with(nil).merge(complicated: false)
      events.each { |event| apply(event) }
    end

    private

    def apply(event)
      case event.kind
      when 'created', 'reopened'
        enter(event, exited_from_stage: nil)
      when 'advanced'
        enter(event)
      when 'held'
        enter(event, held_from_stage: event.from_stage, hold_until: date(event, 'hold_until'), hold_reason: event.body)
      when 'returned_from_hold', 'moved'
        enter(event, **cleared_hold, exited_from_stage: nil)
      when 'exited'
        enter(event, **cleared_hold, exited_from_stage: event.details['resume_stage'])
        state.merge!(cleared_complicated) if event.to_stage == 'withdrawn'
      when 'flagged_complicated'
        state.merge!(complicated: true, complicated_note: event.body,
                     complicated_check_back_on: date(event, 'check_back_on'))
      when 'cleared_complicated'
        state.merge!(cleared_complicated)
      end
    end

    def enter(event, **changes)
      changes[:exited_from_stage] = state[:exited_from_stage] unless changes.key?(:exited_from_stage)
      state.merge!(stage: event.to_stage, stage_entered_at: event.created_at, **changes)
    end

    def date(event, key)
      value = event.details[key]
      value && Date.iso8601(value)
    end

    def cleared_hold = { held_from_stage: nil, hold_until: nil, hold_reason: nil }
    def cleared_complicated = { complicated: false, complicated_note: nil, complicated_check_back_on: nil }
  end
end
