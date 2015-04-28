ActiveAdmin.register User do
  config.batch_actions = false

  permit_params :name, :email, :password, :password_confirmation

  filter :name
  filter :email

  index do
    id_column

    column :name
    column :email
    column(:role) { |u| status_tag u.role }
    column :showcase
    column(:subscription) { |u| status_tag u.subscription.plan.try(:name), (u.subscription.active? ? :active : :inactive) }

    actions
  end

  controller do
    def create
      create!

      if @user.persisted?
        @user.build_subscription.save(validate: false)
      end
    end

    def update_resource(object, attributes)
      if attributes[0][:password].blank? && attributes[0][:password_confirmation].blank?
        attributes[0].delete(:password)
        attributes[0].delete(:password_confirmation)
      end

      object.update_attributes(*attributes)
    end
  end

  form do |f|
    semantic_errors *f.object.errors.keys

    inputs do
      input :name
      input :email
      input :password
      input :password_confirmation
      input :showcase
    end

    actions
  end
end
