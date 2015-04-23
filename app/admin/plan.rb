ActiveAdmin.register Plan do
  config.batch_actions = false

  permit_params :name, :value

  filter :name

  index do
    column :name, sortable: false

    column :value, sortable: :value do |p|
      p.value.format
    end

    column :subscriptions do |p|
      p.subscriptions.count
    end

    actions
  end

  controller do
    def destroy
      destroy!
    rescue ActiveRecord::DeleteRestrictionError => e
      redirect_to admin_plans_path, flash: { error: 'Cannot delete plan as it has subscribers' }
    end
  end

  form do |f|
    semantic_errors *f.object.errors.keys

    inputs do
      input :name
      input :value, label: 'Value in cents' if f.object.new_record?
    end

    actions
  end

end
