class CalculatePayrollService
  def call(start_date, end_date)
    pool = 0

    Payment.where(created_at: start_date..end_date).includes(:plan).each do |p|
      contribution = p.plan.nil? ? 0.1 : p.plan.contribution
      pool += contribution * p.total
    end

    pool
  end
end
