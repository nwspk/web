class ApiController < ApplicationController
  protect_from_forgery with: :null_session

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render json: { status: :no }, status: 401
  end

  def uid
    uid  = params[:uid]
    ring = Ring.find_by! uid: uid

    if ring.eligible_for_entry?
      response = { status: :ok }
    else
      response = { status: :no }
    end

    render json: response, status: 200
  end
end
