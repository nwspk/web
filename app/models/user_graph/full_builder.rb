class UserGraph::FullBuilder < UserGraph::Builder
  def initialize(options = {})
    @user = options[:user]

    if options[:start] && options[:end]
      @range = options[:start]..options[:end]
    else
      @range = false
    end

    @blacklist = Set.new (options[:blacklist] || [])
    @no_staff  = options[:no_staff]
  end

  def build
    graph       = UserGraph::Graph.new(@user)
    friendships = FriendEdge.weighted.includes(from: { subscription: :plan })

    if @range
      friendships = friendships.where(created_at: @range)
    end

    friendships.each do |f|
      next if @blacklist.include?(f.from_id) || @blacklist.include?(f.to_id)
      next if @no_staff && (f.from.excluded_from_graphs? || f.to.excluded_from_graphs?)

      graph.nodes << f.from
      graph.nodes << f.to
      graph.edges << [f.from_id, f.to_id, f.weight]
      graph.edges << [f.to_id, f.from_id, f.weight]
    end

    graph
  end
end
