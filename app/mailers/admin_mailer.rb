class AdminMailer < ApplicationMailer
  def payment_failed_email(failed_user)
    @failed_user = failed_user
    return if no_admins
    mail to: admins, subject: "Payment failed for #{failed_user.name}"
  end

  def new_member_email(new_member)
    @new_member = new_member
    return if no_admins && no_fellows
    mail to: admins + fellows, subject: "New member signed up: #{new_member.name}"
  end

  def new_sponsored_member(new_member)
    @new_member = new_member
    return if no_admins && no_fellows
    mail to: admins, subject: "New member applied for sponsored membership: #{new_member.name}"
  end

  def new_subscriber_email(new_subscriber)
    @new_subscriber = new_subscriber
    return if no_admins
    mail to: admins, subject: "New member became a paid subscriber: #{new_subscriber.name}"
  end

  def staff_reminder_email(reminder, member)
    @member   = member
    @reminder = reminder
    if @member.twitter
      @twitter_username = @member.twitter.try(:username)
      get_twitter_info
    end
    mail to: @reminder.email, subject: "Member reminder: #{@member.name}"
  end

  private

  def admins
    User.admins.pluck(:email)
  end

  def fellows
    User.fellows.pluck(:email)
  end

  def no_admins
    User.admins.count.zero?
  end

  def no_fellows
    User.fellows.count.zero?
  end

  #def get_friends
  #  FriendEdge.find_or_create_by(from: user, to: friend, network: 'twitter')
  #  FriendEdge.find_or_create_by(from: friend, to: user, network: 'twitter')
  #end

  def get_client
    @client ||= Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['TWITTER_KEY']
      config.consumer_secret     = ENV['TWITTER_SECRET']
    end
    @client
  end

  def get_twitter_info
    begin
      twitter_user = get_client.user(@twitter_username)
      @twitter_bio = twitter_user.description
      @twitter_photo = twitter_user.profile_image_url
    rescue Twitter::Error => e
      ""
    end
  end

end
