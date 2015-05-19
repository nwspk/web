class UserGraph::FullBuilder < UserGraph::Builder
  def initialize(options = {})
    @user = options[:user]

    if options[:start] && options[:end]
      @range = options[:start]..options[:end]
    else
      @range = false
    end
  end

  def build
    graph       = UserGraph::Graph.new(@user)
    users       = User.with_subscription.includes(subscription: :plan)
    friendships = FriendEdge.weighted.includes(:from)

    if @range
      friendships = friendships.where(created_at: @range)
    end

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
