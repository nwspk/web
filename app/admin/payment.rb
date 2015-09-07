ActiveAdmin.register Payment do
  config.batch_actions = false
  config.filters = false

  actions :index

  index do
    column('Invoice ID') { |p| p.stripe_invoice_id }
    column(:total) { |p| p.total.format }
    column(:user) { |p| link_to p.user.email, admin_user_path(p.user) }
    column :date
  end

  sidebar "Payroll generation" do
    link_to 'Download payroll CSV for current month', export_payroll_admin_payments_path
  end

  collection_action :export_payroll, method: :get do
    month = Date.today.month
    year  = Date.today.year

    s = CalculatePayrollService.new

    dividend = s.call(month, year)
    dividend = Money.new(dividend, 'GBP').format

    fellows = User.fellows

    str = "Name,E-mail,Dividend\n"
    fellows.each { |f| str << "\"#{f.name}\",\"#{f.email}\",\"#{dividend}\"\n" }

    send_data str, filename: "nwspk-payroll-#{year}-#{month}.csv"
  end
end
