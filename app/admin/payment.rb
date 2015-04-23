ActiveAdmin.register Payment do
  config.batch_actions = false
  config.filters = false

  actions :index

  index do
    column 'Invoice ID' do |p|
      p.stripe_invoice_id
    end

    column 'Total' do |p|
      p.total.format
    end

    column :user do |p|
      link_to p.user.email, admin_user_path(p.user)
    end

    column :date
  end
end
