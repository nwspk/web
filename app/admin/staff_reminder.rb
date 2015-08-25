ActiveAdmin.register StaffReminder do
  config.batch_actions = false
  config.filters = false

  permit_params :email, :frequency, :last_id
end
