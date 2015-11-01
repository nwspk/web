class UserGraph::StrangersBuilder < UserGraph::Builder
  def initialize(options = {})
    @user = options[:user]
  end

  def build
    graph     = UserGraph::Graph.new(nil)
    strangers = FriendEdge.weighted.where('to_id != ? AND from_id != ?', @user.id, @user.id).includes(from: { subscription: :plan })

    graph.nodes << @user

    strangers.each do |s|
      graph.nodes << s.from
      graph.nodes << s.to
      graph.edges << [s.from_id, s.to_id, s.weight]
      graph.edges << [s.to_id, s.from_id, s.weight]
    end

    graph
  end
end
