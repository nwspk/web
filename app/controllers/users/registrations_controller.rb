class Users::RegistrationsController < Devise::RegistrationsController
  def new
    build_resource({})
    resource.build_subscription(plan_id: Plan.first.try(:id))
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

  def after_sign_up_path_for(resource)
    checkout_subscription_path
  end

  private

  def sign_up_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, { subscription_attributes: [:plan_id] })
  end
end
