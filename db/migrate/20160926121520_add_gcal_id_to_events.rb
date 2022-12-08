class AddGcalIdToEvents < ActiveRecord::Migration[4.2]
  def change
    add_column :events, :gcal_id, :string, default: nil, null: true
  end
end
