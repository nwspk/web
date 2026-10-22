module Admissions
  # The eoi-form's wording (SPEC §2 eoi-form, §9): its introduction and its
  # privacy notice. Staff read them; leads change them. Each save is a new
  # version naming who wrote it, and earlier versions stay readable here.
  class FormTextsController < BaseController
    before_action :load_key, only: %i[edit update]

    def index
      authorize! :read, FormText
      @histories = FormText::KEYS.keys.index_with { |key| FormText.history(key).to_a }
      @closed_reasons = EoiForm.closed_reasons
    end

    def edit
      authorize! :create, FormText
      @text = FormText.new(key: @key, body: FormText.current(@key)&.body)
    end

    def update
      authorize! :create, FormText
      @text = FormText.new(key: @key, body: params.dig(:admissions_form_text, :body), created_by_user: current_user)
      @text.validate
      if @text.errors.empty? && @text.body == FormText.current(@key)&.body
        redirect_to admissions_form_texts_path, notice: "#{@text.label}: no change to save."
      elsif @text.save
        redirect_to admissions_form_texts_path, notice: "#{@text.label} saved. The form shows it from now on."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def load_key
      @key = params[:key]
      raise ActiveRecord::RecordNotFound unless FormText::KEYS.key?(@key)
    end
  end
end
