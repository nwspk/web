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

  def description_plaintext
    text = description.to_s.dup
    # Convert Markdown links and images to "text (url)"
    text.gsub!(/!\[([^\]]*)\]\(([^\)]+)\)/, '\\1 (\\2)')
    text.gsub!(/\[([^\]]+)\]\(([^\)]+)\)/, '\\1 (\\2)')
    # Remove emphasis/strong/code markers
    text.gsub!(/[*_]{1,3}([^*_]+)[*_]{1,3}/, '\\1')
    text.gsub!(/`{1,3}([^`]+)`{1,3}/m, '\\1')
    # Strip headings and blockquotes markers
    text.gsub!(/^\s{0,3}#+\s*/, '')
    text.gsub!(/^>\s?/, '')
    # Normalize list markers
    text.gsub!(/^\s*[-*+]\s+/, '- ')
    text.gsub!(/^\s*\d+\.\s+/, '- ')
    # Collapse excessive blank lines
    text.gsub!(/\r\n?/, "\n")
    text.gsub!(/\n{3,}/, "\n\n")
    text.strip
  end
end
