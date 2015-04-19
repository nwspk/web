class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable

  validates :name, presence: true
  validates_associated :subscription

  has_one :address
  has_one :subscription
  has_many :connections

  accepts_nested_attributes_for :subscription

  def facebook
    self.connections.find_by(provider: 'facebook')
  end

  def twitter
    self.connections.find_by(provider: 'twitter')
  end
end
