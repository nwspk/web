ActiveAdmin.register Subscription do
  config.batch_actions = false
  config.filters = false

  actions :index, :show, :edit, :update

  permit_params :plan_id

  scope :all
  scope :with_credit_card

  index do
    column 'User' do |s|
      link_to s.user.email, admin_user_path(s.user)
    end

    column 'Credit card connected' do |s|
      s.customer_id.blank? ? 'No' : 'Yes'
    end

    column 'Plan' do |s|
      s.plan.try(:description) || 'No plan selected'
    end

    column :active_until

    actions defaults: false do |s|
      links = ""
      links << link_to('Change plan', edit_admin_subscription_path(s), class: 'member_link')
      links << link_to('Terminate subscription', terminate_admin_subscription_path(s), method: :post, class: 'member_link')
      links.html_safe
    end
  end

  member_action :terminate, method: :post do
    service = TerminateSubscriptionService.new
    service.call(resource)

    redirect_to resource_path, notice: 'Succesfully terminated subscription'
  end

  controller do
    def update_resource(object, attributes)
      if attributes[0][:plan_id] != object.plan_id
        service = ChangePlanService.new
        service.call(object, attributes[0][:plan_id])
      end
    end
  end

  form do |f|
    inputs do
      input :plan
    end

    actions
  end
end
