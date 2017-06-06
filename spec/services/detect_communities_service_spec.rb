require 'rails_helper'
require 'set'

RSpec.describe DetectCommunitiesService, type: :model do
  let(:users) { 7.times.map { |i| u = Fabricate(:user, name: "User #{i}"); Fabricate(:subscription, user: u, plan: Fabricate(:plan, name: "Plan #{i}")); u } }
  let(:graph) { UserGraph::FullBuilder.new.build }

  before do
    # Community 1
    create_edge(users[0], users[1])
    create_edge(users[0], users[2])
    create_edge(users[1], users[2])

    # Community 2
    create_edge(users[3], users[4])
    create_edge(users[3], users[5])
    create_edge(users[4], users[5])
  end

  describe '#call' do
    it 'detects distinct communities' do
      service = DetectCommunitiesService.new
      service.call(graph)

      communities = Set.new []

      graph.nodes.each { |n| communities.add(n.community) unless communities.include?(n.community) }

      expect(communities.size).to eq 3
    end

    it 'detect connected communities' do
      # Connect communities but in an insignificant proportion
      create_edge(users[0], users[4])
      create_edge(users[4], users[6])
      create_edge(users[6], users[5])
      create_edge(users[3], users[6])

      service = DetectCommunitiesService.new
      service.call(graph)

      communities = Set.new []

      graph.nodes.each { |n| communities.add(n.community) unless communities.include?(n.community) }

      expect(communities.size).to be < 7
    end
  end

  private

  def create_edge(a, b)
    FriendEdge.create(from: a, to: b, network: 'test')
    FriendEdge.create(from: b, to: a, network: 'test')
  end
end
