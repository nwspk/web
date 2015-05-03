class DoorAccess < ActiveRecord::Base
  belongs_to :ring
  belongs_to :user
end
