class DetectCommunitiesService
  def call(graph)
    node_map = {}

    graph.nodes.each do |n|
      node_map[n.id] = Node.new(n)
    end

    graph.edges.each do |e|
      node_map[e[0]].connections << node_map[e[1]]
      node_map[e[1]].connections << node_map[e[0]]
    end

    @graph = node_map.values

    puts "Converted graph"
    puts "Initializing network"
    initialize_network

    puts "Main algorithm"
    while @p < 10
      work
    end

    @graph.each do |n|
      n.user.community = n.community.id
    end

    graph
  end

  private

  def work
    @graph.each do |i|
      community = i.community
      found_communities = []
      new_community = nil
      max = [[], 0]

      # Step 1
      @graph.each do |m|
        val = @neighbours[i.id][m.id]

        if val > max[1]
          max = [[m.community], val]
        elsif val == max[1]
          max[0] << m.community
        end
      end

      found_communities = max[0]
      lm = max[1]

      next if found_communities.empty?

      if found_communities.size > 1
        max = [[], 0]

        found_communities.each do |c|
          s = c.degree_sum

          if s > max[1]
            max = [[c], s]
          elsif s == max[1]
            max[0] << c
          end
        end

        if max[0].size > 1
          new_community = max[0].sample
        elsif max[0].size == 1
          new_community = max[0].first
        else
          raise 'unreachable'
        end
      elsif found_communities.size == 1
        new_community = found_communities.first
      else
        raise 'unreachable'
      end

      # Step 2
      inequality_left  = (3 * @neighbours[i.id][new_community.id] - i.degree) * new_community.num
      inequality_right = new_community.inner_edges - new_community.outer_edges

      if inequality_left > inequality_right
        # (1)
        community.members.delete(i)
        new_community.members << i
        i.community = new_community

        # (2)
        new_community.inner_edges = new_community.inner_edges + lm
        new_community.outer_edges = new_community.outer_edges + i.degree - 2 * lm

        # (3)
        community.inner_edges = community.inner_edges - lm
        community.outer_edges = community.outer_edges - i.degree + 2 * lm

        # (4)
        i.connections.each do |k|
          @neighbours[k.id][community.id]     = @neighbours[k.id][community.id] - 1
          @neighbours[k.id][new_community.id] = @neighbours[k.id][new_community.id] + 1
        end
      end
    end

    @p = @p + 1
  end

  def initialize_network
    @communities = {}
    @neighbours  = Hash.new { |h, k| h[k] = {} }

    @graph.each do |i|
      @communities[i.id] = Community.new(i)
      i.community = @communities[i.id]

      @graph.each do |j|
        @neighbours[i.id][j.id] = 0

        if i.neighbour_with? j
          @neighbours[i.id][j.id] = 1
        end
      end
    end

    @p = 0
  end

  class Community
    attr_accessor :id, :members, :inner_edges, :outer_edges

    def initialize(first_member)
      @id          = first_member.id
      @members     = [first_member]
      @inner_edges = 0
      @outer_edges = first_member.degree
    end

    def num
      @members.size
    end

    def degree_sum
      @members.inject(0) { |sum, x| sum + x.degree }
    end
  end

  class Node
    attr_accessor :user, :connections, :community

    def initialize(user)
      @user = user
      @connections = []
    end

    def id
      @user.id
    end

    def degree
      @connections.size
    end

    def neighbour_with?(other)
      @connections.include? other
    end
  end
end
