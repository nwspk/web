class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    if user.ed?
      can :manage, :all
    end
  end
end
