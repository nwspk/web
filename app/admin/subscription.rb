ActiveAdmin.register Subscription do
  config.filters = false

  index do
    column 'User' do |s|
      s.user.email
    end

    column 'Plan' do |s|
      s.plan.try(:description) || 'No plan selected'
    end

    column :active_until

    actions defaults: false do |s|
      link_to 'Terminate subscription', terminate_admin_subscription_path(s), method: :post
    end
  end

  member_action :terminate, method: :post do
    # todo
  end
end
