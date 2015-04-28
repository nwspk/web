class SeedRandomFriendGraphService
  def call(clusters_num, nodes_num, edges_num)
    clusters = []
    nodes    = []

    clusters_num.times do |i|
      clusters << {
        id: i,
        nodes: []
      }
    end

    nodes_num.times do |i|
      cluster = clusters.sample
      user = Fabricate(:user)
      nodes << user
      cluster[:nodes] << user
    end

    edges_num.times do |i|
      if Random.rand < 0.5
        create_edge(nodes.sample, nodes.sample)
      else
        cluster = clusters.sample
        create_edge(cluster[:nodes].sample, cluster[:nodes].sample)
      end
    end
  end

  private

  def create_edge(a, b, network = 'twitter')
    FriendEdge.create(from: a, to: b, network: network)
    FriendEdge.create(from: b, to: a, network: network)
  end
end
