class Event < ActiveRecord::Base
  validates :name, :start_at, :end_at, :url, :location, :organiser_name, :organiser_email, :organiser_url, :description, :status, presence: true
  enum status: [:proposed, :confirmed, :rejected]

  scope :public_and_confirmed, -> { confirmed.where(public: true) }
  scope :upcoming,             -> { where('end_at > ?', Time.now).order('start_at asc') }
  scope :archive,              -> { where('end_at < ?', Time.now).order('start_at desc') }

  def money_value
    Money.new(self.value, 'GBP')
  end

  def description_html
    Rails.cache.fetch("event_description_#{id}_#{updated_at.to_i}") do
      Kramdown::Document.new(description).to_html.html_safe
    end
  end

  def formatted_date_details
    Rails.cache.fetch("event_date_#{id}_#{start_at.to_i}_#{end_at.to_i}") do
      start_date = start_at.strftime('%a %d %^b %Y')
      start_time = start_at.strftime('%l:%M%P').strip
      end_time = end_at.strftime('%l:%M%P').strip
      "#{start_date} • #{start_time} – #{end_time} • #{location}"
    end
  end
end
