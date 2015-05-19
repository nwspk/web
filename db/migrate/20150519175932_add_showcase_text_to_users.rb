class AddShowcaseTextToUsers < ActiveRecord::Migration
  def change
    add_column :users, :showcase_text, :string, null: false, default: ""
  end
end
