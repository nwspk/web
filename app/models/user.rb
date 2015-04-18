class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable

  validates :name, presence: true
  validates_associated :subscription

  has_one :address
  has_one :subscription

  accepts_nested_attributes_for :subscription
end
