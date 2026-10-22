module Admissions
  # The kanban-board's columns for one round (SPEC §2 kanban-board, §3a): one
  # per funnel stage that isn't terminal, in funnel order, then on hold, then
  # "it's complicated". A flagged applicant shows only in the complicated
  # column, whatever their stage or hold, confirmed included (the flag
  # decides where the card shows, SPEC §3; every exit clears it). Applicants
  # who have finished (confirmed, or any exit) are kept apart in #finished,
  # which the board shows collapsed.
  #
  # Within a column the card that has sat longest comes first.
  class Board
    COMPLICATED = 'complicated'.freeze
    COLUMNS = (Stages::FUNNEL - Stages::TERMINAL + [Stages::ON_HOLD, COMPLICATED]).freeze
    FINISHED = Stages::TERMINAL

    attr_reader :round

    def initialize(round)
      @round = round
    end

    def self.column_for(applicant)
      applicant.complicated? ? COMPLICATED : applicant.stage
    end

    def self.column_label(column)
      column == COMPLICATED ? "It's complicated" : Stages.label(column)
    end

    # { column => [applicant, …] } for every column, empty ones included.
    def columns
      @columns ||= COLUMNS.index_with { |column| grouped.fetch(column, []) }
    end

    # { terminal state => [applicant, …] }, in Stages::TERMINAL order.
    def finished
      @finished ||= FINISHED.index_with { |state| grouped.fetch(state, []) }
    end

    # { applicant_id => { 'held' => n, 'sending' => n } }: what each card is
    # waiting to send, for its "held for approval" marker.
    def waiting_emails
      @waiting_emails ||= Email.where(applicant_id: applicants.map(&:id), status: %w[held sending])
                               .group(:applicant_id, :status).count
                               .each_with_object(Hash.new { |h, k| h[k] = {} }) do |((id, status), n), out|
        out[id][status] = n
      end
    end

    private

    def applicants
      @applicants ||= round.applicants.order(:stage_entered_at, :id).to_a
    end

    def grouped
      @grouped ||= applicants.group_by { |applicant| self.class.column_for(applicant) }
    end
  end
end
