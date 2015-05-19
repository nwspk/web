require 'set'

class UserGraph::Graph
  attr_reader :center, :nodes, :edges

  def initialize(center)
    @center = center
    @nodes  = Set.new []
    @edges  = Set.new []
  end

  def to_json
    {
      center: @center.nil? ? nil : "n#{@center.id}",
      nodes: build_nodes_json,
      edges: build_edges_json
    }.to_json
  end

  def to_gdf(options = {})
    str = "nodedef> name VARCHAR, label VARCHAR, plan_type VARCHAR, size INT\n"
    @nodes.each { |n| str << "#{n.id}, #{n.name}, #{plan_type(n)}, #{plan_to_size(n)}\n"}
    str << "edgedef> user VARCHAR, friend VARCHAR\n"
    @edges.each { |e| str << "#{e[0]}, #{e[1]}\n"}
    str
  end

  private

  def build_nodes_json
    @nodes.map.with_index do |x, i|
      {
        id: "n#{x.id}",
        label: "#{x.name}",
        community: x.community,
        x: circular_x(i),
        y: circular_y(i),
        size: plan_to_size(x),
        showcase: x.showcase,
        plan_type: plan_type(x),
        showcase_text: x.showcase_text,
        url: x.url
      }
    end
  end

  def build_edges_json
    @edges.map.with_index { |x, i| { id: "e#{i}", source: "n#{x[0]}", target: "n#{x[1]}", weight: x[2] } }
  end

  def circular_x(i)
    100 * Math.cos(2 * i * Math::PI / @nodes.size)
  end

  def circular_y(i)
    100 * Math.sin(2 * i * Math::PI / @nodes.size)
  end

  def plan_to_size(user)
    return 1.0 if (user.subscription.nil? || !user.subscription.active? || user.subscription.plan.nil?)
    1.0 + Math.log10(user.subscription.plan.value.cents + 100)
  end

  def plan_type(user)
    return :inactive if user.subscription.nil? || !user.subscription.active?
    user.subscription.plan.name
  end
end
