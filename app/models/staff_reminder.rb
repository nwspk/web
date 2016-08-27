class StaffReminder < ActiveRecord::Base
  validates :email, :frequency, presence: true
  validates :last_id, :frequency, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :set_default_last_id

  def due?(time = Time.now)
    self.last_run_at.nil? || (self.last_run_at < (time - self.frequency.hours))
  end

  def pop!
    new_id = self.last_id
    max_id = User.maximum('id')
    loops  = 0

    begin
      new_id = new_id + 1

      if new_id > max_id
        loops  = loops + 1
        new_id = 1
      end

      next_user = User.find(new_id)

      raise UnwantedUser unless next_user.eligible_for_reminders?
    rescue ActiveRecord::RecordNotFound, UnwantedUser
      return nil if loops > 2
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
