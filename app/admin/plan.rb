ActiveAdmin.register Plan do
  permit_params :name, :value, :stripe_id

  filter :name
  filter :stripe_id, label: "Associated Stripe plan"

  index do
    selectable_column
    column :name, sortable: false

    column :value, sortable: :value do |p|
      Money.new(p.value, 'GBP').format
    end

    column "Associated Stripe plan", :stripe_id, sortable: false
    actions
  end

  form do |f|
    semantic_errors

    inputs do
      input :name
      input :value, label: 'Value in cents'
      input :stripe_id, label: 'Stripe plan ID'
    end

    actions
  end

end
