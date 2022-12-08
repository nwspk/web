class CreateAddresses < ActiveRecord::Migration[4.2]
  def change
    create_table :addresses do |t|
      t.belongs_to :user, unique: true
      t.string :recipient
      t.string :street
      t.string :city
      t.string :postal_code
      t.string :country

      t.timestamps null: false
    end
  end
end
