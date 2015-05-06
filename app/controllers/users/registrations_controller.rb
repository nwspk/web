class Users::RegistrationsController < Devise::RegistrationsController
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

  def resource_class
    PublicUser
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
end
