ActiveAdmin.register StaffReminder do
  config.batch_actions = false
  config.filters = false

  actions :index, :new, :create, :edit, :update, :destroy

  permit_params :email, :frequency, :last_id, :active

  index do
    column :email
    column :frequency
    column :active

    column :last_member do |r|
      User.find(r.last_id).name
    rescue ActiveRecord::RecordNotFound
      'None yet'
    end

    column :last_run do |r|
      if r.last_run_at.nil?
        'Never'
      else
        "#{time_ago_in_words(r.last_run_at)} ago"
      end
    end

    actions
  end

  form do |f|
    semantic_errors(*f.object.errors.keys)

    inputs do
      input :email
      input :frequency, label: 'Frequeny in whole hours'
      input :last_id, label: 'Last user ID'
      input :active
    end

    actions
  end
end
