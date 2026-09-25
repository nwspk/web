ActiveAdmin.register User do
  config.batch_actions = false

  permit_params :name, :email, :password, :password_confirmation, :showcase, :url, :showcase_text, :role, :notes, :avatar

  filter :name
  filter :email

  scope :all
  scope :with_subscription
  scope :fellows
  scope :alumni
  scope :staff
  scope :admins
  scope :guests
  scope :founders
  scope :inactive
  scope :applicants

  sidebar 'Extra User Details', only: [:show, :edit] do
    ul do
      li(link_to('Subscription', admin_subscription_path(user.subscription))) unless user.subscription.nil?
    end
  end

  index do
    id_column

    column :name
    column :email
    column(:role) { |u| status_tag u.role }
    column :showcase
    column :showcase_text
    column(:subscription) { |u| status_tag u.subscription.try(:plan_name), class: (u.subscription.try(:active?) ? :active : :inactive) }

    actions
  end

  show do
    attributes_table do
      row :name
      row :email
      row(:avatar) { |u| image_tag u.avatar_url || 'default-face.jpg' }
      row :created_at
      row(:role) { |u| status_tag u.role }
      row :showcase
      row :url
      row :showcase_text
      row :application_text
      row(:subscription) { |u| status_tag u.subscription.try(:plan_name), class: (u.subscription.try(:active?) ? :active : :inactive) }
      row :notes
    end
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

      object.update(*attributes)
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    inputs do
      input :name
      input :email
      input :password
      input :password_confirmation
      input :showcase
      input :url
      input :showcase_text
      input :avatar, as: :file

      input :role, as: :select, collection: User::ROLES if current_user.id != user.id

      input :notes
    end

    actions
  end
end
