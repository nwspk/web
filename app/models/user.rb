class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable

  validates :name, presence: true
  validates_associated :subscription

  has_one :address, dependent: :destroy
  has_one :subscription, dependent: :destroy
  has_many :connections, dependent: :destroy

  has_many :friends, -> { includes(:to) }, class_name: 'FriendEdge', foreign_key: 'from_id', dependent: :destroy
  has_many :followers, class_name: 'FriendEdge', foreign_key: 'to_id', dependent: :destroy

  accepts_nested_attributes_for :subscription

  def facebook
    @facebook_cache ||= self.connections.find_by(provider: 'facebook')
  end

  def twitter
    @twitter_cache ||= self.connections.find_by(provider: 'twitter')
  end
end
