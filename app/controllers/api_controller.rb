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
    start_date = Chronic::parse(params[:from] || '30 days ago')
    end_date   = Chronic::parse(params[:to]   || 'today')

    s = CalculatePayrollService.new

    dividend = s.call(start_date, end_date)
    dividend = Money.new(dividend, 'GBP').format

    str = "Total dividends\n#{dividend}"

    respond_to do |format|
      format.csv { render body: str, content_type: 'text/csv' }
    end
  end
end
