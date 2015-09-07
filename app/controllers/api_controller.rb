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
      ring.record_entry!
      render json: response, status: 200
    else
      response = { status: :no }
      render json: response, status: 401
    end
  end

  def dividends
    month = (params[:month] || Date.today.month).to_i
    year  = (params[:year] || Date.today.year).to_i

    s = CalculatePayrollService.new

    dividend = s.call(month, year)
    dividend = Money.new(dividend, 'GBP').format

    fellows = User.fellows

    str = "Name,E-mail,Dividend\n"
    fellows.each { |f| str << "\"#{f.name}\",\"#{f.email}\",\"#{dividend}\"\n" }

    respond_to do |format|
      format.csv { render body: str, content_type: 'text/csv' }
    end
  end
end
