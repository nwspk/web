class CreateRings < ActiveRecord::Migration[4.2]
  def change
    create_table :rings do |t|
      t.belongs_to :user, index: true
      t.string :uid, null: false, default: ""

      t.timestamps null: false
    end
  end
end
