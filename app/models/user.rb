class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable

  validates :name, presence: true
  validates_associated :subscription

  has_one :address
  has_one :subscription
  has_many :connections
  has_many :friends, -> { includes(:to) }, class_name: 'FriendEdge', foreign_key: 'from_id'

  accepts_nested_attributes_for :subscription

  def facebook
    @facebook_cache ||= self.connections.find_by(provider: 'facebook')
  end

  def twitter
    @twitter_cache ||= self.connections.find_by(provider: 'twitter')
  end
end
