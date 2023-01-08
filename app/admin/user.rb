ActiveAdmin.register User do
  config.batch_actions = false

  permit_params :name, :email, :password, :password_confirmation, :showcase, :url, :showcase_text, :ring_size, :role, :notes, :avatar

  filter :name
  filter :email
  filter :rings_uid_matches, as: :string, label: 'Ring UID'

  scope :all
  scope :with_rings
  scope :without_rings
  scope :with_subscription
  scope :fellows
  scope :alumni
  scope :staff
  scope :admins
  scope :guests
  scope :founders
  scope :inactive
  scope :applicants

  controller do
    def scoped_collection
      super.with_last_ring
    end
  end

  sidebar 'Extra User Details', only: [:show, :edit] do
    ul do
      li(link_to('Facebook', user.facebook.profile_url)) unless user.facebook.nil?
      li(link_to('Twitter', user.twitter.profile_url)) unless user.twitter.nil?
      li(link_to('Rings', admin_user_rings_path(user)))
      li(link_to('Subscription', admin_subscription_path(user.subscription))) unless user.subscription.nil?

      user.friends.each do |f|
        li(link_to(f.to.name, admin_user_path(f.to)))
      end
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
    column('Last ring', sortable: :last_ring_created_at, &:last_ring_created_at)

    actions
  end

  show do
    attributes_table do
      row :name
      row :email
      row(:avatar) { |u| image_tag u.avatar_url || 'stock-profile-image.jpg' }
      row :created_at
      row(:role) { |u| status_tag u.role }
      row :showcase
      row :url
      row :showcase_text
      row :application_text
      row :ring_size
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
      input :ring_size, as: :select, collection: Ring::SIZES
      input :avatar, as: :file

      input :role, as: :select, collection: User::ROLES if current_user.id != user.id

      input :notes
    end

    actions
  end
end
