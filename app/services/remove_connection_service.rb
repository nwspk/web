class RemoveConnectionService
  def call(connection)
    FriendEdge.where(network: connection.provider).where('to_id = ? OR from_id = ?', connection.user_id, connection.user_id).destroy_all
    connection.destroy
  end
end
