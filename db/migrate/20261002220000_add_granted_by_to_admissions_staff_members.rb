# Who granted each admissions staff role. Kept nullable, and nulled if that
# user is deleted, so removing the granting account never removes the role.
class AddGrantedByToAdmissionsStaffMembers < ActiveRecord::Migration[7.2]
  def change
    add_reference :admissions_staff_members, :granted_by_user,
                  foreign_key: { to_table: :users, on_delete: :nullify }
  end
end
