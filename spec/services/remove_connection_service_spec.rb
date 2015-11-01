require 'rails_helper'

RSpec.describe RemoveConnectionService, type: :model do
  let(:connection) { Fabricate(:connection, user_id: 1) }

  before do
    12.times { |i| FriendEdge.create(from_id: 1, to_id: i + 1, network: connection.provider) }
  end

  it 'removes associated friend edges' do
    s = RemoveConnectionService.new
    s.(connection)

    expect(connection.destroyed?).to be true
    expect(FriendEdge.where(network: connection.provider).count).to eql 0
  end
end
