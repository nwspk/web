class ExportController < ApplicationController
  respond_to :csv

  def users
    string = CSV.generate do |csv|
      csv << ['User ID', 'Name', 'E-mail', 'Role', 'Subscription Tier', 'Facebook', 'Twitter', 'Join Date']

      User.recent.includes(:connections, subscription: :plan).find_each do |user|
        csv << [user.id, user.name, user.email, user.role, user.subscription.try(:plan_name), user.facebook.try(:profile_url), user.twitter.try(:username), user.created_at.utc.iso8601]
      end
    end

    render body: string, content_type: 'text/csv'
  end

  def connections
    string = CSV.generate do |csv|
      csv << %w(From To Platform Timestamp)

      FriendEdge.find_each do |edge|
        csv << [edge.from_id, edge.to_id, edge.network, edge.created_at.utc.iso8601]
      end
    end

    render body: string, content_type: 'text/csv'
  end

  def entries
    string = CSV.generate do |csv|
      csv << %w(Timestamp User)

      DoorAccess.includes(:user).find_each do |access|
        csv << [access.created_at.utc.iso8601, access.user_id]
      end
    end

    render body: string, content_type: 'text/csv'
  end
end
