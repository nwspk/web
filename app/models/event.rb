class Event < ActiveRecord::Base
  validates :name, :start_at, :end_at, :url, :location, :organiser_name, :organiser_email, :organiser_url, :description, :status, presence: true
  enum status: [:proposed, :confirmed, :rejected]

  scope :public_and_confirmed, -> { confirmed.where(public: true) }
  scope :upcoming,             -> { where('end_at > ?', Time.now) }
  scope :archive,              -> { where('end_at < ?', Time.now).order('start_at desc') }

  def money_value
    Money.new(self.value, 'GBP')
  end

  after_initialize :preset_datetimes

  private

  def preset_datetimes
    today = Time.now.utc.to_date
    self.start_at = Time.new(today.year, today.month, today.day, 19, 00, 00, 00)
    self.end_at   = Time.new(today.year, today.month, today.day, 22, 00, 00, 00)
  end
end
