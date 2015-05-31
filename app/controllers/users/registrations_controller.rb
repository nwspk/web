class Users::RegistrationsController < Devise::RegistrationsController
  skip_before_filter :require_no_authentication, only: :new

  def new
    return if user_signed_in?

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
    if [:new, :create].include? action_name
      return PublicUser
    end

    User
  end

  def after_sign_up_path_for(resource)
    checkout_subscription_path
  end

  def build_resource(hash=nil)
    super

    if self.resource.subscription.nil?
      self.resource.build_subscription(plan_id: Plan.first.try(:id))
    end
  end

  private

  def sign_up_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, { subscription_attributes: [:plan_id] })
  end

  def account_update_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :ring_size)
  end
end
