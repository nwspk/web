module Admissions
  # The approval queue (SPEC §3a "Email modes", Q33): every held email,
  # shared among staff, each of whom can edit, send or discard it. Every
  # action is attributed to the staff member who took it.
  class EmailsController < BaseController
    before_action :load_email, only: %i[update discard]

    def index
      authorize! :read, Email
      @emails = Email.held.includes(applicant: :round).order(:drafted_at, :id)
    end

    # Saves the text as shown on the form; with Send, sends it too. Edits
    # are saved, and logged, before the send.
    def update
      sender.edit!(@email, subject: email_params[:subject], body: email_params[:body])
      if params[:send_email]
        sender.send_held!(@email)
        redirect_to admissions_emails_path, notice: "Sent to #{@email.to_address}."
      else
        redirect_to queue_anchor, notice: 'Changes saved. The email is still waiting to be sent.'
      end
    rescue ActiveRecord::RecordInvalid => e
      # Show the queue again with what was typed, so no edit is lost.
      @refused = e.record
      index
      flash.now[:alert] = "Not saved: #{e.record.errors.full_messages.to_sentence}."
      render :index, status: :unprocessable_entity
    rescue Delivery::Error => e
      redirect_to queue_anchor, alert: "Not sent, and still waiting: #{e.message}."
    end

    def discard
      sender.discard!(@email)
      redirect_to admissions_emails_path, notice: 'Email discarded. It will not be sent.'
    end

    rescue_from EmailSender::NotSendable do |e|
      redirect_to admissions_emails_path, alert: "Nothing done: #{e.message}."
    end

    private

    def load_email
      @email = Email.find(params[:id])
      authorize! :update, @email
    end

    def sender
      EmailSender.new(Actor.staff(current_user))
    end

    def email_params
      params.require(:admissions_email).permit(:subject, :body)
    end

    def queue_anchor
      admissions_emails_path(anchor: "email-#{@email.id}")
    end
  end
end
