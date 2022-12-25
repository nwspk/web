class AddShowcaseTextToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :showcase_text, :string, null: false, default: ""
  end
end
