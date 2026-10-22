module Admissions
  # The eoi-form at /admissions (SPEC §2, §9a): the one admissions page
  # anyone can open, so it wears the site's own layout rather than the staff
  # screens'. Admissions::EoiForm does the work; this controller adds the
  # abuse guards, which use no third party (no CAPTCHA, no outside script):
  #
  # - the honeypot: a field people never see, so only a bot fills it. A
  #   submission that fills it gets the ordinary thank-you and saves nothing;
  # - a per-IP rate limit, counted in the site's cache under a keyed hash of
  #   the address. No IP address is stored in the database or the event log.
  class EoiFormController < ApplicationController
    layout 'subpage'

    HONEYPOT = :website
    RATE_LIMIT = 10
    RATE_LIMIT_WINDOW = 1.hour

    rate_limit to: RATE_LIMIT, within: RATE_LIMIT_WINDOW, only: :create,
               by: -> { OpenSSL::HMAC.hexdigest('SHA256', Rails.application.secret_key_base, request.remote_ip) },
               with: -> { refuse_over_rate_limit }

    def show
      @form = EoiForm.new
      render_form
    end

    def create
      if params[HONEYPOT].present?
        # Answer exactly as a success would, so a bot learns nothing.
        logger.warn('EOI honeypot sprung; nothing saved')
        return redirect_to admissions_eoi_thanks_path
      end

      @form = EoiForm.new(eoi_params)
      if @form.save
        redirect_to admissions_eoi_thanks_path
      else
        render_form(status: :unprocessable_entity)
      end
    rescue EoiForm::Closed
      render :closed
    end

    def thanks; end

    private

    # A refused submission may be a real person's lost EOI, so it leaves a
    # trace in the log: no IP, no address, only that it happened.
    def refuse_over_rate_limit
      logger.warn('[admissions] EOI rate limit hit; submission refused')
      render :rate_limited, status: :too_many_requests
    end

    def eoi_params
      eoi = params[:eoi]
      eoi.respond_to?(:permit) ? eoi.permit(:email, :phone) : {}
    end

    def render_form(status: :ok)
      return render(:closed) unless EoiForm.open?

      @introduction = FormText.text('eoi_introduction')
      @privacy_notice = FormText.text('privacy_notice')
      render :show, status: status
    end
  end
end
