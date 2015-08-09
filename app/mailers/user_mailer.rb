class UserMailer < ApplicationMailer
  helper ApplicationHelper

  def billing_email(user, time = Time.now)
    @user        = user
    @new_users   = User.created_after_date(time - 30.days)
    @num_users   = User.count

    @num_connections     = @user.friends.count('distinct to_id')
    @num_new_connections = @user.friends.where('friend_edges.created_at > ?', time - 30.days).count('distinct to_id')

    mail to: user.email, subject: "Monthly summary"
  end
end
