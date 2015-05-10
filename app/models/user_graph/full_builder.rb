class UserGraph::FullBuilder < UserGraph::Builder
  def build
    graph       = UserGraph::Graph.new(nil)
    users       = User.with_subscription
    friendships = FriendEdge.weighted.includes(:from)

    users.each do |u|
      graph.nodes << u
    end

    friendships.each do |f|
      graph.nodes << f.from
      graph.nodes << f.to
      graph.edges << [f.from_id, f.to_id, f.weight]
      graph.edges << [f.to_id, f.from_id, f.weight]
    end

    graph
  end
end
