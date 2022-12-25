class AddApplicationTextToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :application_text, :text, default: '', null: false
  end
end
