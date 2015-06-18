class PublicUser < User
  validates :subscription, presence: true
  validates :url, absence: true
end
