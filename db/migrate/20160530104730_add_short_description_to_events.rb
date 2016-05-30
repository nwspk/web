class AddShortDescriptionToEvents < ActiveRecord::Migration
  def change
    add_column :events, :short_description, :text, default: '', null: false
  end
end
