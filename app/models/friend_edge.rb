class FriendEdge < ActiveRecord::Base
  belongs_to :from, class_name: 'User'
  belongs_to :to, class_name: 'User'

  scope :weighted, -> { group(:from_id, :to_id).select('count(friend_edges.id) as weight, from_id, to_id').includes(to: { subscription: :plan }) }
end
