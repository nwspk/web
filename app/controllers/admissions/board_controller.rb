module Admissions
  # The kanban-board (SPEC §2): one round's applicants in columns by stage,
  # with on-hold and "it's complicated" columns. It shows the round the EOI
  # form is filling unless another is chosen. No drag and drop yet: each
  # card opens the applicant's page, where the actions are.
  class BoardController < BaseController
    def show
      authorize! :read, Applicant
      @rounds = Round.order(Arel.sql('opens_on DESC NULLS LAST'), id: :desc).to_a
      @round = params[:round].present? ? Round.find(params[:round]) : EoiForm.round || @rounds.first
      @board = Board.new(@round) if @round
    end
  end
end
