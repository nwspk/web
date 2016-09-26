class AddGcalIdToEvents < ActiveRecord::Migration
  def change
    add_column :events, :gcal_id, :string, default: nil, null: true
  end
end
