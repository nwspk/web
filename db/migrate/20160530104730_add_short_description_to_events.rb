class AddShortDescriptionToEvents < ActiveRecord::Migration[4.2]
  def change
    add_column :events, :short_description, :text, default: '', null: false
  end
end
