ActiveAdmin.register Plan do
  config.batch_actions = false

  permit_params :name, :value, :visible, :contribution, :stripe_id

  filter :name

  index do
    column :name, sortable: false
    column :stripe_id
    column(:value, sortable: :value) { |p| p.value.format }
    column(:contribution) { |p| "#{p.contribution * 100}%" }
    column(:subscriptions) { |p| p.subscriptions.count }
    column :visible

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
      input :stripe_id
      input :visible
      input :value, label: 'Value in cents' if f.object.new_record?
      input :contribution, label: 'Contribution between 0 and 1'
    end

    actions
  end

end
