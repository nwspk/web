class CreatePayments < ActiveRecord::Migration[4.2]
  def change
    create_table :payments do |t|
      t.belongs_to :user, index: true
      t.integer :total
      t.string :stripe_invoice_id, null: false, default: ""
      t.datetime :date

      t.timestamps null: false
    end
  end
end
