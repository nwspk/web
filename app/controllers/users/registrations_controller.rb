class Users::RegistrationsController < Devise::RegistrationsController
  skip_before_filter :require_no_authentication, only: :new

  def new
    return if user_signed_in?

    build_resource
    @validatable = true
    @minimum_password_length = User.password_length.min

    @total_pledged = Plan.total_pledged
    @total_members = User.with_subscription.count
    @goal_percent  = (@total_pledged.cents / (200000 * 100)) * 100

    respond_with self.resource
  end

  def create
    super do |resource|
      sign_in resource_name, resource if resource.persisted?
    end
  end

  protected

  def update_resource(resource, params)
    if params[:password].blank?
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
    resource.applicant == "1" ? dashboard_path : checkout_subscription_path
  end

  private

  def sign_up_params
    params.require(:user).permit(:name, :email, :url, :password, :password_confirmation, :sponsor, :applicant, :application_text)
  end

  def account_update_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :ring_size)
  end
end
