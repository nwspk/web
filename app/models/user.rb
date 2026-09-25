class User < ActiveRecord::Base
  # Sign-in is via emailed magic links; database_authenticatable remains so
  # existing password mechanics (and the random per-account passwords set at
  # registration) stay valid, but no UI asks for a password.
  devise :magic_link_authenticatable, :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable, :lockable

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

  mount_uploader :avatar, AvatarUploader

  validates :name, presence: true
  validates :role, inclusion: ROLES.values
  validates :url, format: { with: %r{\Ahttps?://}i, message: 'must start with http:// or https://' }, allow_blank: true
  validates_associated :subscription

  has_one :subscription, dependent: :destroy

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

  scope :with_subscription,  -> { joins(:subscription).where.not(subscriptions: { subscription_id: '' }) }
  scope :created_after_date, -> (date) { where('created_at > ?', date) }

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

  # Devise :trackable, minus the IP addresses: sign-in counts and times are a
  # useful sign of whether an account is used, but nothing ever read the IPs,
  # so they were personal data held for no purpose (columns dropped
  # 2026-09-24). Mirrors Devise 4.9's own update_tracked_fields otherwise.
  def update_tracked_fields(_request)
    old_current, new_current = current_sign_in_at, Time.now.utc
    self.last_sign_in_at     = old_current || new_current
    self.current_sign_in_at  = new_current

    self.sign_in_count ||= 0
    self.sign_in_count += 1
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
