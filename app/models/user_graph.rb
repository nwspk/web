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

  def self.centered_on_user(user, options = {})
    options[:max_depth] ||= 5

    graph       = self.new(user)
    open_list   = []
    closed_list = []

    open_list << [user, 0]

    while !open_list.empty?
      cur, depth = open_list.pop

      closed_list << cur.id
      graph.nodes << cur

      cur.friends.group(:to_id).select('count(friend_edges.id) as weight, to_id').each do |f|
        next if options[:showcase_only] && !f.to.showcase

        graph.edges << [cur.id, f.to_id, f.weight]

        unless closed_list.include?(f.to_id) || (depth + 1) > options[:max_depth]
          open_list << [f.to, depth + 1]
        end
      end
    end

    graph
  end

  def self.full(options = {})
    if options[:showcase_only]
      offset = Random.rand(User.where(showcase: true).count)
      random_starting_user = User.where(showcase: true).offset(offset).first
    else
      offset = Random.rand(User.count)
      random_starting_user = User.offset(offset).first
    end

    centered_on_user(random_starting_user, options)
  end

  private

  def build_nodes_json
    @nodes.uniq.map.with_index do |x, i|
      {
        id: x.id.to_s,
        label: x.name,
        x: circular_x(i),
        y: circular_y(i),
        size: plan_to_size(x.subscription.plan),
        showcase: x.showcase
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

  def plan_to_size(plan)
    Math.log10(plan.value)
  end
end
