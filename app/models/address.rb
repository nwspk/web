class Address < ActiveRecord::Base
  belongs_to :user

  validates :recipient, :street, :city, :postal_code, :country, presence: true
end
