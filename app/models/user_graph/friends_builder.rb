class UserGraph::FriendsBuilder < UserGraph::Builder
  def initialize(options = {})
    @user          = options[:user]
    @max_depth     = options[:max_depth]     || 5
    @showcase_only = options[:showcase_only] || false
  end

  def build
    @graph       = UserGraph::Graph.new(@user)
    @open_list   = []
    @closed_list = []

    add_to_queue(0, @user)

    while @open_list.size > 0
      cur, depth = @open_list.pop

      mark_visited(cur)

      get_child_nodes(cur).each do |f|
        next if skip_showcase_requested(f)
        add_to_graph(cur, f)
        add_to_queue(depth + 1, f.to) unless already_visited(f) || reached_max_depth(depth)
      end
    end

    @graph
  end

  private

  def skip_showcase_requested(f)
    @showcase_only && !f.to.showcase
  end

  def add_to_queue(depth, node)
    @open_list   << [node, depth]
    @graph.nodes << node
  end

  def add_to_graph(cur, f)
    @graph.edges << [cur.id, f.to_id, f.weight]
    @graph.nodes << f.to
  end

  def mark_visited(cur)
    @closed_list << cur.id
  end

  def get_child_nodes(cur)
    cur.friends.weighted
  end

  def already_visited(f)
    @closed_list.include?(f.to_id)
  end

  def reached_max_depth(depth)
    (depth + 1) > @max_depth
  end
end
