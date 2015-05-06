class PublicUser < User
  validates :subscription, presence: true
end
