class Event < ActiveRecord::Base
  validates :name, :start_at, :end_at, :url, :location, :organiser_name, :organiser_email, :organiser_url, :description, :status, presence: true
  enum status: [:proposed, :confirmed, :rejected]

  scope :public_and_confirmed, -> { confirmed.where(public: true) }
  scope :upcoming,             -> { where('end_at > ?', Time.now).order('start_at asc') }
  scope :archive,              -> { where('end_at < ?', Time.now).order('start_at desc') }

  def money_value
    Money.new(self.value, 'GBP')
  end
end
