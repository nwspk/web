ActiveAdmin.register Ring do
  belongs_to :user

  config.filters = false

  permit_params :user_id, :uid

  index do
    selectable_column
    column :uid
  end
end
