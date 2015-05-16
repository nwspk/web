class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable

  ROLES = {
    admin: 'admin',
    member: 'member'
  }

  attr_accessor :community

  validates :name, presence: true
  validates :role, inclusion: ROLES.values
  validates_associated :subscription
  validates :ring_size, inclusion: Ring::SIZES, unless: 'ring_size.nil?'

  has_one :address, dependent: :destroy
  has_one :subscription, dependent: :destroy
  has_many :connections, dependent: :destroy
  has_many :rings, dependent: :destroy
  has_many :door_accesses, dependent: :destroy

  has_many :friends, -> { includes(:to) }, class_name: 'FriendEdge', foreign_key: 'from_id', dependent: :destroy
  has_many :followers, class_name: 'FriendEdge', foreign_key: 'to_id', dependent: :destroy

  accepts_nested_attributes_for :subscription

  before_validation :set_default_role
  after_create :notify_admins
  before_destroy :terminate_subscription

  scope :admins, -> { where(role: ROLES[:admin]) }
  scope :with_subscription, -> { joins(:subscription).where.not(subscriptions: { subscription_id: '' }) }

  def facebook
    @facebook_cache ||= self.connections.find_by(provider: 'facebook')
  end

  def twitter
    @twitter_cache ||= self.connections.find_by(provider: 'twitter')
  end

  def admin?
    self.role == ROLES[:admin]
  end

  def discount
    Money.new(self.friends.count('distinct to_id') * 100, 'GBP')
  end

  def needs_ring_size?
    self.ring_size.nil?
  end

  private

  def set_default_role
    self.role = ROLES[:member] if self.role.blank?
  end

  def notify_admins
    AdminMailer.new_member_email(self).deliver_later
  end

  def terminate_subscription
    return if self.subscription.nil?
    service = TerminateSubscriptionService.new
    service.call(self.subscription)
    return
  end
end
