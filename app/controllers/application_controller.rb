class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :configure_permitted_parameters, if: :devise_controller?
  layout :layout_by_resource

  def route_not_found
    render 'errors/404', status: :not_found
  end

  protected

  def access_denied(exception)
    redirect_to dashboard_path, alert: exception.message
  end

  def after_sign_in_path_for(resource)
    dashboard_path
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
  end

  def layout_by_resource
    if devise_controller?
      "subpage"
    else
      "application"
    end
  end
end
