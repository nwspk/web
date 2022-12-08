class AddNotesToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :notes, :text
  end
end
