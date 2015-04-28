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
end
