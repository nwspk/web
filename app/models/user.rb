class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable

  ROLES = {
    ed: 'ed',
    member: 'member'
  }

  validates :name, presence: true
  validates :role, inclusion: ROLES.values
  validates_associated :subscription

  has_one :address, dependent: :destroy
  has_one :subscription, dependent: :destroy
  has_many :connections, dependent: :destroy

  has_many :friends, -> { includes(:to) }, class_name: 'FriendEdge', foreign_key: 'from_id', dependent: :destroy
  has_many :followers, class_name: 'FriendEdge', foreign_key: 'to_id', dependent: :destroy

  accepts_nested_attributes_for :subscription

  before_validation :set_default_role

  def facebook
    @facebook_cache ||= self.connections.find_by(provider: 'facebook')
  end

  def twitter
    @twitter_cache ||= self.connections.find_by(provider: 'twitter')
  end

  def ed?
    self.role == ROLES[:ed]
  end

  private

  def set_default_role
    self.role = ROLES[:member] if self.role.blank?
  end
end
