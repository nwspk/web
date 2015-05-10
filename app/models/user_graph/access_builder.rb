class UserGraph::AccessBuilder < UserGraph::Builder
  def initialize(options = {})
    @start_date  = options[:start]     || 1.day.ago
    @end_date    = options[:end]       || 1.day.from_now
    @user        = options[:user]
  end

  def build
    user_subset_ids = DoorAccess.where(created_at: @start_date..@end_date).select('distinct user_id').pluck(:user_id)
    user_subset     = User.where(id: user_subset_ids)

    return empty_graph if user_subset.size < 1

    graph       = UserGraph::Graph.new(@user)
    friendships = FriendEdge.where(from_id: user_subset_ids).weighted.includes(:from)

    user_subset.each do |u|
      graph.nodes << u
    end

    friendships.each do |f|
      if user_subset_ids.include? f.to_id
        graph.edges << [f.from_id, f.to_id, f.weight]
        graph.edges << [f.to_id, f.from_id, f.weight]
      end
    end

    graph
  end

  private

  def empty_graph
    UserGraph::Graph.new(nil)
  end
end
