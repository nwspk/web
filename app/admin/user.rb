ActiveAdmin.register User do
  config.batch_actions = false

  permit_params :name, :email, :password, :password_confirmation, :showcase, :url, :showcase_text, :ring_size, :role

  filter :name
  filter :email

  scope :all
  scope :with_subscription
  scope :fellows
  scope :staff
  scope :admins

  sidebar "User Details", only: [:show, :edit] do
    ul do
      li link_to "Rings",    admin_user_rings_path(user)
      li(link_to("Subscription", admin_subscription_path(user.subscription))) unless user.subscription.nil?

      user.friends.each do |f|
        li link_to f.to.name, admin_user_path(f.to)
      end
    end
  end

  index do
    id_column

    column :name
    column :email
    column(:role) { |u| status_tag u.role }
    column :showcase
    column :url
    column(:subscription) { |u| status_tag u.subscription.try(:plan_name), (u.subscription.try(:active?) ? :active : :inactive) }

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
      input :url
      input :showcase_text
      input :ring_size, as: :select, collection: Ring::SIZES

      if current_user.id != user.id
        input :role, as: :select, collection: User::ROLES
      end
    end

    actions
  end
end
