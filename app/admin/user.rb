ActiveAdmin.register User do
  config.batch_actions = false

  permit_params :name, :email, :password, :password_confirmation

  filter :name
  filter :email

  index do
    id_column
    column :name
    column :email

    column :role do |u|
      status_tag u.role
    end

    column "Subscription" do |u|
      link_to (u.subscription.active? ? u.subscription.plan.name : "Inactive"), admin_subscription_path(u.subscription)
    end

    actions
  end

  controller do
    def update_resource(object, attributes)
      if attributes[0][:password].blank? && attributes[0][:password_confirmation].blank?
        attributes[0].delete(:password)
        attributes[0].delete(:password_confirmation)
      end

      object.update_attributes(*attributes)
    end
  end

  form do |f|
    semantic_errors

    inputs do
      input :name
      input :email

      unless f.object.new_record?
        f.input :password
        f.input :password_confirmation
      end
    end

    actions
  end
end
