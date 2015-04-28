class UserGraph
  attr_reader :center, :nodes, :edges

  def initialize(center)
    @center = center
    @nodes  = []
    @edges  = []
  end

  def to_json
    {
      nodes: build_nodes_json,
      edges: build_edges_json
    }.to_json
  end

  def self.centered_on_user(user)
    graph       = self.new(user)
    open_list   = []
    closed_list = []

    open_list << user

    while !open_list.empty?
      cur = open_list.pop

      closed_list << cur.id
      graph.nodes << cur

      cur.friends.group(:to_id).select('count(friend_edges.id) as weight, to_id').each do |f|
        graph.edges << [cur.id, f.to_id, f.weight]

        unless closed_list.include? f.to_id
          open_list << f.to
        end
      end
    end

    graph
  end

  def self.full(showcase_only = false)
  end

  # class WorkNode
  #   attr_accessor :user, :depth
  # end

  private

  def build_nodes_json
    @nodes.uniq.map.with_index do |x, i|
      followers = x.followers.count

      {
        id: x.id.to_s,
        label: x.name,
        x: circular_x(i),
        y: circular_y(i),
        size: Math.log10(followers),
        data: {
          followers: followers,
          showcase: x.showcase
        }
      }
    end
  end

  def build_edges_json
    @edges.uniq.map.with_index { |x, i| { id: "e#{i}", source: x[0].to_s, target: x[1].to_s, weight: x[2] } }
  end

  def circular_x(i)
    100 * Math.cos(2 * i * Math::PI / @nodes.uniq.size)
  end

  def circular_y(i)
    100 * Math.sin(2 * i * Math::PI / @nodes.uniq.size)
  end
end
