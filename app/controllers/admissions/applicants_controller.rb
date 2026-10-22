module Admissions
  # The applicant's page (SPEC §2 admin-dashboard, §3a): the card in full,
  # with its details, upcoming emails, correspondence and history, and the
  # actions staff take on it. Every action goes through
  # Admissions::ApplicantChanges, attributed to whoever pressed it. Also the
  # form for cards created by hand, and the lists the staff home's counts
  # link to.
  class ApplicantsController < BaseController
    DUE_LISTS = {
      'check_back' => "It's complicated: check-back date come",
      'hold_return' => 'On hold: return date come'
    }.freeze

    before_action :load_applicant, except: %i[index new create]

    # The cards behind one of the staff home's counts.
    def index
      authorize! :read, Applicant
      @due = params[:due]
      return redirect_to(admissions_board_path) unless DUE_LISTS.key?(@due)

      scope = @due == 'check_back' ? Applicant.check_back_due : Applicant.hold_return_due
      @applicants = scope.includes(:round).order(@due == 'check_back' ? :complicated_check_back_on : :hold_until, :id)
    end

    def show
      @events = @applicant.events.reorder(id: :desc).includes(:actor_user).to_a
      @correspondence = @events.select { |event| event.kind == 'email_sent' }
      @upcoming = UpcomingEmails.for(@applicant)
      @person_records = @applicant.person_records - [@applicant]
    end

    def new
      authorize! :create, Applicant
      @card = CardByHand.new(round_id: params[:round].presence || EoiForm.round&.id)
    end

    # Two steps when the stage offers emails: Continue shows each one's
    # preview with an unticked box, then Create card creates it and sends
    # what was ticked, refusing if the texts changed since the preview.
    def create
      authorize! :create, Applicant
      @card = CardByHand.new(card_params)
      creating = params[:create].present?
      @card.send_emails = params.dig(:card, :send_emails) if creating
      return render_card_form(:unprocessable_entity) unless @card.valid?

      if @card.offered_emails.any? && !creating
        return render_card_form
      elsif @card.send_emails.any? && params[:preview_digest] != @card.preview_digest
        flash.now[:alert] = 'The emails changed since you saw them. Check them again before creating the card.'
        return render_card_form(:unprocessable_entity)
      end

      if @card.save(Actor.staff(current_user))
        redirect_to admissions_applicant_path(@card.applicant), notice: created_notice
      else
        render_card_form(:unprocessable_entity)
      end
    end

    def note
      changes.add_note!(@applicant, body: params[:body].to_s.strip)
      done 'Note added.'
    end

    def pause_emails
      changes.pause_emails!(@applicant)
      done "Automatic email to #{who} is paused."
    end

    def resume_emails
      changes.resume_emails!(@applicant)
      done "Automatic email to #{who} is back on."
    end

    def flag_complicated
      changes.flag_complicated!(@applicant, note: params[:note].to_s.strip, check_back_on: date_param(:check_back_on))
      done "Flagged \"it's complicated\". No automatic email goes to #{who} until the flag is cleared."
    end

    def clear_complicated
      changes.clear_complicated!(@applicant)
      done "\"It's complicated\" cleared. The card is back in its stage's column."
    end

    def hold
      changes.hold!(@applicant, until_date: date_param(:hold_until), reason: params[:reason].to_s.strip)
      done "On hold until #{l(@applicant.hold_until, format: :long)}."
    end

    def return_from_hold
      changes.return_from_hold!(@applicant)
      done "Returned from hold to #{Stages.label(@applicant.stage)}."
    end

    # Move to any stage, step one: what the move will do, to confirm.
    def confirm_move
      @to = params[:to].to_s
      unless Stages::FUNNEL.include?(@to) && @to != @applicant.stage
        return redirect_to(admissions_applicant_path(@applicant), alert: 'Choose a different stage to move to.')
      end

      @preview = changes.preview_move(@applicant, to: @to)
    end

    def move
      changes.move!(@applicant, to: params[:to].to_s, note: params[:note].to_s.strip)
      done "Moved to #{Stages.label(@applicant.stage)}. No email was sent."
    end

    def defer
      changes.exit!(@applicant, to: 'deferred', note: params[:note].to_s.strip)
      done 'Deferred: kept for next round.'
    end

    def reopen
      changes.reopen!(@applicant)
      done "Reopened at #{Stages.label(@applicant.stage)}."
    end

    # Withdrawal, step one: exactly what will be erased, to confirm.
    def confirm_withdraw
      authorize! :withdraw, @applicant
      return redirect_to(admissions_applicant_path(@applicant), alert: 'Already withdrawn.') if @applicant.withdrawn?

      @person_records = @applicant.person_records - [@applicant]
    end

    def withdraw
      authorize! :withdraw, @applicant
      unless params[:confirm] == '1'
        return redirect_to(withdraw_admissions_applicant_path(@applicant),
                           alert: 'Nothing done: tick the box to confirm the erasure first.')
      end

      changes.withdraw!(@applicant)
      done 'Withdrawn. Their details on this record are erased.'
    end

    rescue_from ApplicantChanges::IllegalChange, ApplicantChanges::NotPermitted do |e|
      redirect_to admissions_applicant_path(@applicant), alert: "Nothing done: #{e.message}."
    end

    rescue_from ActiveRecord::RecordInvalid do |e|
      redirect_to admissions_applicant_path(@applicant),
                  alert: "Nothing done: #{e.record.errors.full_messages.to_sentence}."
    end

    private

    def load_applicant
      @applicant = Applicant.find(params[:id])
      authorize! :update, @applicant
    end

    def changes
      ApplicantChanges.new(Actor.staff(current_user))
    end

    def done(notice)
      redirect_to admissions_applicant_path(@applicant), notice: notice
    end

    def who
      @applicant.display_name
    end

    # A date typed in a form (yyyy-mm-dd), or nil; the service says what's
    # missing.
    def date_param(key)
      Date.iso8601(params[key].to_s)
    rescue Date::Error
      nil
    end

    def card_params
      params.fetch(:card, {}).permit(:round_id, :email, :phone, :name, :stage, :first_interest_on)
    end

    # The previews show once everything typed is valid.
    def render_card_form(status = :ok)
      @previews = @card.previews if @card.errors.empty? && @card.offered_emails.any?
      render :new, status: status
    end

    def created_notice
      sent = @card.emails.map do |email|
        case email.status
        when 'sent' then "#{email.label} sent."
        when 'held' then "#{email.label} not sent: it's waiting in the approval queue."
        else "#{email.label}: the outcome is unknown. See the approval queue."
        end
      end
      (["Card created for #{@card.applicant.display_name}."] + sent).join(' ')
    end
  end
end
