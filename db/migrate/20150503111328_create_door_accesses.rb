class CreateDoorAccesses < ActiveRecord::Migration[4.2]
  def change
    create_table :door_accesses do |t|
      t.belongs_to :ring, index: true, null: false
      t.belongs_to :user, index: true, null: false

      t.timestamps null: false
    end
  end
end
