class AddApplicationTextToUsers < ActiveRecord::Migration
  def change
    add_column :users, :application_text, :text, default: '', null: false
  end
end
