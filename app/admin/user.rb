ActiveAdmin.register User do
  permit_params :name, :email

  filter :name
  filter :email

  index do
    id_column
    column :name
    column :email

    column "Subscription" do |u|
      link_to (u.subscription.active? ? u.subscription.plan.name : "Inactive"), admin_subscription_path(u.subscription)
    end

    actions
  end

  form do |f|
    semantic_errors

    inputs do
      input :name
      input :email
    end

    actions
  end
end
