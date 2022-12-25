class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable

  ROLES = {
    admin: 'admin',
    staff: 'staff',
    fellow: 'fellow',
    member: 'member',
    guest: 'guest',
    alumnus: 'alumnus',
    founder: 'founder',
    inactive: 'inactive',
    applicant: 'applicant'
  }.freeze

  attr_accessor :community

  mount_uploader :avatar, AvatarUploader

  validates :name, presence: true
  validates :role, inclusion: ROLES.values
  validates_associated :subscription
  validates :ring_size, inclusion: Ring::SIZES, unless: -> { ring_size.nil? }

  has_one :address, dependent: :destroy
  has_one :subscription, dependent: :destroy
  has_many :connections, dependent: :destroy
  has_many :rings, dependent: :destroy
  has_many :door_accesses, dependent: :destroy

  has_many :friends, -> { includes(:to) }, class_name: 'FriendEdge', foreign_key: 'from_id', dependent: :destroy
  has_many :followers, class_name: 'FriendEdge', foreign_key: 'to_id', dependent: :destroy

  has_one :twitter,  -> { where(provider: 'twitter') },  class_name: 'Connection'
  has_one :facebook, -> { where(provider: 'facebook') }, class_name: 'Connection'

  accepts_nested_attributes_for :subscription

  before_validation :set_default_role
  after_create :notify_admins
  before_destroy :terminate_subscription

  scope :admins,     -> { where(role: ROLES[:admin]) }
  scope :staff,      -> { where(role: ROLES[:staff]) }
  scope :fellows,    -> { where(role: ROLES[:fellow]) }
  scope :guests,     -> { where(role: ROLES[:guest]) }
  scope :alumni,     -> { where(role: ROLES[:alumnus]) }
  scope :founders,   -> { where(role: ROLES[:founder]) }
  scope :inactive,   -> { where(role: ROLES[:inactive]) }
  scope :applicants, -> { where(role: ROLES[:applicant]) }
  scope :recent,     -> { where(role: (ROLES.values - [ROLES[:inactive], ROLES[:guest], ROLES[:applicant]])).order('id desc') }

  scope :with_subscription,  -> { joins(:subscription).where.not(subscriptions: { subscription_id: '' }) }
  scope :created_after_date, -> (date) { where('created_at > ?', date) }
  scope :with_last_ring,     -> { select('users.*, (SELECT created_at FROM rings WHERE user_id = users.id ORDER BY created_at desc LIMIT 1) AS last_ring_created_at') }
  scope :with_rings,         -> { with_last_ring.joins('LEFT OUTER JOIN rings ON rings.user_id = users.id ').group('users.id').having('count(rings.id) > 0') }
  scope :without_rings,      -> { with_last_ring.joins('LEFT OUTER JOIN rings ON rings.user_id = users.id ').group('users.id').having('count(rings.id) = 0') }

  def admin?
    self.role == ROLES[:admin]
  end

  def staff?
    self.role == ROLES[:staff]
  end

  def admin_or_staff?
    admin? || staff?
  end

  def excluded_from_graphs?
    admin_or_staff? || guest? || inactive? || applicant?
  end

  def eligible_for_reminders?
    !excluded_from_graphs?
  end

  def fellow?
    self.role == ROLES[:fellow]
  end

  def alumnus?
    self.role == ROLES[:alumnus]
  end

  def guest?
    self.role == ROLES[:guest]
  end

  def founder?
    self.role == ROLES[:founder]
  end

  def inactive?
    self.role == ROLES[:inactive]
  end

  def applicant?
    self.role == ROLES[:applicant]
  end

  def overrides_entry_rules?
    admin_or_staff? || fellow? || guest? || alumnus? || founder?
  end

  def discount
    Money.new(self.friends.count('distinct to_id') * 100, 'GBP')
  end

  def needs_ring_size?
    self.ring_size.nil?
  end

  private

  def set_default_role
    self.role = ROLES[:applicant] if self.role.blank?
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
