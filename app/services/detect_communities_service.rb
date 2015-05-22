require 'louvian'

class DetectCommunitiesService
  def call(graph)
    nodes_list = graph.nodes.to_a
    edge_list  = graph.edges.map { |e| e.take(2).map { |n| nodes_list.index { |_n| _n.id == n } } }

    Louvian::Community.reset

    Louvian::Community.class_eval do
      define_method :level do
        @level
      end
    end

    l = Louvian.new(edge_list, true)
    l.run

    return if l.levels.size < 1

    node_map = {}

    l.levels.each do |graph|
      graph.communities.each do |comm|
        node_map[comm.id] = comm
      end
    end

    l.levels.last.communities.each do |comm|
      comm_nodes = collect_basic_nodes(node_map, comm)

      comm_nodes.each do |i|
        nodes_list[i].community = comm.id
      end
    end
  end

  private

  def collect_basic_nodes(node_map, comm)
    return comm.nodes_ids if comm.level == 0

    comm.nodes_ids.flat_map do |id|
      collect_basic_nodes(node_map, node_map[id])
    end
  end
end
