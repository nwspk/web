ActiveAdmin.register StaffReminder do
  config.batch_actions = false
  config.filters = false

  actions :index, :new, :create, :edit, :update, :destroy

  permit_params :email, :frequency, :last_id

  index do
    column :email
    column :frequency

    column :last_member do |r|
      begin
        User.find(r).name
      rescue ActiveRecord::RecordNotFound
        "None yet"
      end
    end

    column :last_run do |r|
      time_ago_in_words(r.last_run_at) + " ago"
    end

    actions
  end

  form do |f|
    semantic_errors *f.object.errors.keys

    inputs do
      input :email
      input :frequency, label: 'Frequeny in whole hours'
      input :last_id, label: 'Last user ID'
    end

    actions
  end
end
