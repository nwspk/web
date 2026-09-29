# Drops the tables and columns of features retired long ago, so the data
# they held (old OAuth tokens, postal addresses, door-entry logs, sign-in IPs)
# is no longer kept for no purpose:
#
# - connections, friend_edges: the Twitter/Facebook member graph (removed 2022)
# - addresses: postal addresses, unread since ~2016
# - rings, door_accesses, users.ring_size: the NFC door-ring system, whose
#   door endpoint was unrouted in June 2022
# - events.gcal_id, plans.contribution, staff_reminders.string: never read
# - users.current_sign_in_ip / last_sign_in_ip: see User#update_tracked_fields
#
# Rolling back recreates the empty structure only; the data is gone. Take a
# pg_dump of these tables before running this in production.
class DropRetiredFeatures < ActiveRecord::Migration[7.2]
  def change
    drop_table :connections, id: :serial do |t|
      t.integer :user_id
      t.string :provider, default: '', null: false
      t.string :uid, default: '', null: false
      t.string :access_token, default: '', null: false
      t.string :secret
      t.datetime :expires_at, precision: nil
      t.datetime :created_at, precision: nil, null: false
      t.datetime :updated_at, precision: nil, null: false
      t.string :profile_url
      t.string :username, default: '', null: false
      t.index %w[provider uid], name: 'index_connections_on_provider_and_uid', unique: true
      t.index :user_id, name: 'index_connections_on_user_id'
    end

    drop_table :friend_edges, id: :serial do |t|
      t.integer :from_id, null: false
      t.integer :to_id, null: false
      t.string :network, default: '', null: false
      t.datetime :created_at, precision: nil, null: false
      t.datetime :updated_at, precision: nil, null: false
      t.index :from_id, name: 'index_friend_edges_on_from_id'
      t.index :to_id, name: 'index_friend_edges_on_to_id'
    end

    drop_table :addresses, id: :serial do |t|
      t.integer :user_id
      t.string :recipient
      t.string :street
      t.string :city
      t.string :postal_code
      t.string :country
      t.datetime :created_at, precision: nil, null: false
      t.datetime :updated_at, precision: nil, null: false
      t.index :user_id, name: 'index_addresses_on_user_id'
    end

    drop_table :door_accesses, id: :serial do |t|
      t.integer :ring_id, null: false
      t.integer :user_id, null: false
      t.datetime :created_at, precision: nil, null: false
      t.datetime :updated_at, precision: nil, null: false
      t.index :ring_id, name: 'index_door_accesses_on_ring_id'
      t.index :user_id, name: 'index_door_accesses_on_user_id'
    end

    drop_table :rings, id: :serial do |t|
      t.integer :user_id
      t.string :uid, default: '', null: false
      t.datetime :created_at, precision: nil, null: false
      t.datetime :updated_at, precision: nil, null: false
      t.index :user_id, name: 'index_rings_on_user_id'
    end

    remove_column :users, :ring_size, :float
    remove_column :users, :current_sign_in_ip, :string
    remove_column :users, :last_sign_in_ip, :string
    remove_column :events, :gcal_id, :string
    remove_column :plans, :contribution, :float, default: 0.0, null: false
    remove_column :staff_reminders, :string, :string, default: '', null: false
  end
end
