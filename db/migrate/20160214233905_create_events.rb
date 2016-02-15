class CreateEvents < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.string :name, null: false, default: ''
      t.datetime :start_at, null: false
      t.datetime :end_at, null: false
      t.string :url, null: false, default: ''
      t.text :location, null: false
      t.string :organiser_name, null: false, default: ''
      t.string :organiser_email, null: false, default: ''
      t.string :organiser_url, null: false, default: ''
      t.text :description, null: false
      t.boolean :public, null: false
      t.integer :status
      t.integer :value
      t.text :notes, null: false

      t.timestamps null: false
    end
  end
end
