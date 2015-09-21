class Connection < ActiveRecord::Base
  belongs_to :user

  def expired?
    !self.expires_at.nil? && self.expires_at < Time.now
  end
end
