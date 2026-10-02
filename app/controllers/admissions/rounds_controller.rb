module Admissions
  # Rounds and their settings. Officers read; leads also create and edit.
  class RoundsController < BaseController
    before_action :load_round, only: %i[show edit update]

    def index
      @rounds = Round.order(Arel.sql('opens_on DESC NULLS LAST'), id: :desc)
      @stage_counts = Applicant.group(:round_id, :stage).count
      @complicated_counts = Applicant.where(complicated: true).group(:round_id).count
    end

    def show; end

    def new
      authorize! :create, Round
      @round = Round.new
    end

    def create
      authorize! :create, Round
      @round = Round.new(round_params)
      if @round.save
        redirect_to admissions_round_path(@round), notice: 'Round created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize! :update, @round
    end

    def update
      authorize! :update, @round
      if @round.update(round_params)
        redirect_to admissions_round_path(@round), notice: 'Round settings saved.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def load_round
      @round = Round.find(params[:id])
    end

    def round_params
      permitted = params.require(:admissions_round).permit(
        :name, :opens_on, :invites_on, :closes_on, :reminder_interval_days,
        *Round::MONEY_FIELDS.map { |f| :"#{f}_pounds" },
        email_modes: EmailTypes.keys, staff_turnaround_days: Round.staff_stages
      )
      if permitted.key?(:staff_turnaround_days)
        # A blank turnaround means the default; anything else must be days.
        days = permitted[:staff_turnaround_days].to_h.compact_blank
        permitted[:staff_turnaround_days] = days.transform_values { |d| Integer(d, 10, exception: false) || d }
      end
      permitted[:email_modes] = permitted[:email_modes].to_h if permitted.key?(:email_modes)
      permitted
    end
  end
end
