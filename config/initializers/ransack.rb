# Ransack 4 (pulled in by ActiveAdmin 3) requires every model to allowlist
# which attributes/associations are searchable; without these methods the
# admin filter sidebars raise. Search is only reachable through ActiveAdmin,
# which sits behind admin authentication, so restore the pre-4.0 behaviour
# of allowing all columns instead of annotating every model.
ActiveSupport.on_load(:active_record) do
  def self.ransackable_attributes(_auth_object = nil)
    column_names + _ransackers.keys
  end

  def self.ransackable_associations(_auth_object = nil)
    reflect_on_all_associations.map { |a| a.name.to_s }
  end
end
