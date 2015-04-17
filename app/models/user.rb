class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable

  validates :name, presence: true

  has_one :address
  has_one :subscription

  accepts_nested_attributes_for :subscription
end
