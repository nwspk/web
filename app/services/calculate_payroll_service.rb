class CalculatePayrollService
  def call(month, year)
    pool = 0
    begin_date = Date.new(year, month, 1)

    Payment.where(created_at: begin_date..begin_date.next_month).includes(:plan).each do |p|
      contribution = p.plan.nil? ? 0.1 : p.plan.contribution
      pool += contribution * p.total
    end

    num_fellows = User.fellows.count

    return if num_fellows == 0

    dividend = pool / num_fellows
    dividend
  end
end
