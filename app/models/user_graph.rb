class UserGraph
  attr_reader :center, :nodes, :edges

  def initialize(center)
    @center = center
    @nodes  = []
    @edges  = []
  end

  def to_json
    {
      center: "n#{@center.id}",
      nodes: build_nodes_json,
      edges: build_edges_json
    }.to_json
  end

  def self.centered_on_user(user, options = {})
    options[:max_depth] ||= 5

    graph       = self.new(user)
    open_list   = []
    closed_list = []

    open_list   << [user, 0]
    graph.nodes << user

    while !open_list.empty?
      cur, depth = open_list.pop

      closed_list << cur.id

      cur.friends.group(:to_id).select('count(friend_edges.id) as weight, to_id').each do |f|
        next if options[:showcase_only] && !f.to.showcase

        graph.edges << [cur.id, f.to_id, f.weight]
        graph.nodes << f.to

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
        id: "n#{x.id}",
        label: x.name,
        x: circular_x(i),
        y: circular_y(i),
        size: plan_to_size(x),
        showcase: x.showcase,
        plan_type: plan_type(x)
      }
    end
  end

  def build_edges_json
    @edges.uniq.map.with_index { |x, i| { id: "e#{i}", source: "n#{x[0]}", target: "n#{x[1]}", weight: x[2] } }
  end

  def circular_x(i)
    100 * Math.cos(2 * i * Math::PI / @nodes.uniq.size)
  end

  def circular_y(i)
    100 * Math.sin(2 * i * Math::PI / @nodes.uniq.size)
  end

  def plan_to_size(user)
    return 1 if user.subscription.nil? || !user.subscription.active?
    Math.log10(user.subscription.plan.value.cents)
  end

  def plan_type(user)
    return :inactive if user.subscription.nil? || !user.subscription.active?
    user.subscription.plan.name
  end
end
