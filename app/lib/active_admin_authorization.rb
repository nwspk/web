# ActiveAdmin is for site admins only. The Ability alone isn't enough to keep
# it that way: admissions officers can read admissions records through the
# Ability (for the /admissions area), and must not reach them through
# /admin. So every ActiveAdmin check needs a site admin first, then the
# Ability as before — which also keeps a site admin without an admissions
# role out of the admissions resources.
class ActiveAdminAuthorization < ActiveAdmin::CanCanAdapter
  def authorized?(action, subject = nil)
    user.respond_to?(:admin?) && user.admin? && super
  end
end
