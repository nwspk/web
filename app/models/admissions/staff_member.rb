module Admissions
  # A site user who is admissions staff (SPEC §9b "Auth and staff"). Separate
  # from users.role, so an existing admin or staff user can also hold an
  # admissions role; nobody is admissions staff by being a site admin.
  class StaffMember < ActiveRecord::Base
    ROLES = %w[lead officer].freeze

    belongs_to :user

    validates :role, inclusion: { in: ROLES }
    validates :user_id, uniqueness: true

    def self.for(user)
      return nil if user.nil? || user.new_record?

      find_by(user_id: user.id)
    end

    def lead? = role == 'lead'
    def officer? = role == 'officer'
  end
end
