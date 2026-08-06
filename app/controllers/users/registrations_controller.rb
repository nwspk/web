class Users::RegistrationsController < Devise::RegistrationsController
  skip_before_action :require_no_authentication, only: :new
  before_action :set_progress, only: [:new, :create]

  def new
    build_resource
    @validatable = true
    @minimum_password_length = User.password_length.min

    respond_with self.resource
  end

  def create
    super do |resource|
      sign_in resource_name, resource if resource.persisted?
    end
  end

  protected

  def update_resource(resource, params)
    email_changing = params[:email].present? && params[:email] != resource.email

    # Allow no-password updates for low-risk fields (e.g. ring_size), but require
    # the current password whenever the password OR the email is being changed —
    # otherwise an open session could silently take over the account by swapping
    # the email and triggering a password reset.
    if params[:password].blank? && !email_changing
      params.delete(:password)
      params.delete(:password_confirmation)
      params.delete(:current_password)
      resource.update_without_password(params)
    else
      super(resource, params)
    end
  end

  def resource_class
    if [:new, :create].include? action_name.to_sym
      return PublicUser
    end

    User
  end

  def after_sign_up_path_for(resource)
    AdminMailer.new_sponsored_member(resource).deliver_later if resource.applicant == '1'
    resource.applicant == '1' ? dashboard_path : checkout_subscription_path
  end

  private

  def sign_up_params
    params.require(:user).permit(:name, :email, :url, :password, :password_confirmation, :sponsor, :applicant, :application_text)
  end

  def account_update_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :ring_size)
  end

  def set_progress
    @total_pledged = Plan.total_pledged
    @total_members = User.with_subscription.count
  end
end
