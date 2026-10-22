module Admissions
  # A round's email templates (SPEC §4: editable per round). Staff read
  # them; leads write them. The wording lives only in the database.
  class EmailTemplatesController < BaseController
    before_action :load_round
    before_action :load_template, only: %i[edit update]

    def index
      authorize! :read, EmailTemplate
      @templates = @round.email_templates.index_by(&:email_type)
    end

    def new
      authorize! :create, EmailTemplate
      @template = @round.email_templates.new(email_type: params[:email_type])
      raise ActiveRecord::RecordNotFound unless EmailTypes::TYPES.key?(@template.email_type)
    end

    def create
      authorize! :create, EmailTemplate
      type = params.dig(:admissions_email_template, :email_type)
      @template = @round.email_templates.new(template_params.merge(email_type: type))
      save_template(:new)
    end

    def edit
      authorize! :update, @template
    end

    def update
      authorize! :update, @template
      @template.assign_attributes(template_params)
      save_template(:edit)
    end

    private

    def load_round
      @round = Round.find(params[:round_id])
    end

    def load_template
      @template = @round.email_templates.find(params[:id])
    end

    def template_params
      permitted = params.require(:admissions_email_template).permit(:subject, :body)
      permitted[:body] = permitted[:body].gsub("\r\n", "\n") if permitted[:body]
      permitted
    end

    def save_template(form)
      @template.updated_by_user = current_user
      if @template.save
        redirect_to admissions_round_email_templates_path(@round), notice: "#{@template.label} template saved."
      else
        render form, status: :unprocessable_entity
      end
    end
  end
end
