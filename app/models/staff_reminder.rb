class StaffReminder < ActiveRecord::Base
  validates :email, :frequency, presence: true
  validates :last_id, :frequency, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :set_default_last_id

  def due?(time = Time.now)
    self.last_run_at < (time - self.frequency.hours)
  end

  def pop!
    new_id = self.last_id
    max_id = User.maximum('id')

    begin
      new_id = new_id + 1

      if new_id > max_id
        new_id = 1
      end

      next_user = User.find(new_id)

      if next_user.admin_or_staff?
        raise UnwantedUser
      end
    rescue ActiveRecord::RecordNotFound
      retry
    rescue UnwantedUser
      retry
    end

    self.last_id     = new_id
    self.last_run_at = Time.now
    self.save!

    next_user
  end

  private

  def set_default_last_id
    if self.last_id.blank?
      self.last_id = 0
    end
  end

  class UnwantedUser < StandardError
  end
end
