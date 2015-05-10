class UserGraph::AccessBuilder < UserGraph::Builder
  def initialize(options = {})
    @start_date  = options[:start]     || 1.day.ago
    @end_date    = options[:end]       || 1.day.from_now
    @max_depth   = options[:max_depth] || 5
  end

  def build
    user_subset = DoorAccess.where(created_at: @start_date..@end_date).select('distinct user_id').pluck(:user_id)

    return empty_graph if user_subset.size == 0

    offset               = Random.rand(user_subset.size)
    random_starting_user = User.offset(offset).first

    graph       = UserGraph::Graph.new(random_starting_user)
    open_list   = []
    closed_list = []

    open_list   << [random_starting_user, 0]
    graph.nodes << random_starting_user

    while !open_list.empty?
      cur, depth = open_list.pop

      closed_list << cur.id

      get_child_nodes(cur).each do |f|
        graph.edges << [cur.id, f.to_id, f.weight]
        graph.nodes << f.to

        unless closed_list.include?(f.to_id) || (depth + 1) > @max_depth
          open_list << [f.to, depth + 1]
        end
      end
    end

    graph
  end

  private

  def empty_graph
    UserGraph::Graph.new(nil)
  end

  def get_child_nodes(cur)
    cur.friends.weighted
  end
end
